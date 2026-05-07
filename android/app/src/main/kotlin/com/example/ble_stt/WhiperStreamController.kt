// Controls the offline STT streaming process on Android.
// Captures microphone audio using AudioRecord,
// stores recent audio in a rolling buffer,
// repeatedly sends audio to whisper.cpp for transcription,
// and returns the latest transcript to Flutter.

package com.example.ble_stt

import android.Manifest
import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.annotation.RequiresPermission
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread
import kotlin.math.max

class WhisperStreamController(
    private val modelPath: String,
    private val threads: Int,
    private val eventCallback: (Map<String, Any>) -> Unit
) {
    private val sampleRate = 16000

    private var contextPtr: Long = 0L

    private var audioRecord: AudioRecord? = null
    private var audioThread: Thread? = null
    private var decodeThread: Thread? = null

    private val isRunning = AtomicBoolean(false)
    private val bufferLock = Any()
    private val audioBuffer = ArrayList<Float>()

    private var lastTranscript = ""

    fun init() {
        if (contextPtr != 0L) return

        contextPtr = WhisperNative.initContext(
            modelPath = modelPath,
            threads = threads
        )

        if (contextPtr == 0L) {
            throw IllegalStateException("Failed to initialise whisper context")
        }

        sendStatus("Native whisper context created")
    }

    @SuppressLint("MissingPermission")
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    fun startStreaming(
        stepMs: Int,
        windowMs: Int,
        keepMs: Int,
        language: String,
        audioCtx: Int
    ) {
        if (contextPtr == 0L) {
            throw IllegalStateException("Whisper context is not initialised")
        }

        if (isRunning.get()) {
            sendStatus("STT is already running")
            return
        }

        isRunning.set(true)
        lastTranscript = ""

        synchronized(bufferLock) {
            audioBuffer.clear()
        }

        val windowSamples = sampleRate * windowMs / 1000
        val minDecodeSamples = sampleRate // Start decoding after around 1 second

        startAudioCapture(windowSamples)
        startDecodeLoop(
            stepMs = stepMs,
            windowSamples = windowSamples,
            minDecodeSamples = minDecodeSamples,
            language = language,
            audioCtx = audioCtx
        )

        sendStatus("Audio capture started")
    }

    private fun startAudioCapture(windowSamples: Int) {
        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val bufferSize = max(minBufferSize, sampleRate)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        val recorder = audioRecord
            ?: throw IllegalStateException("Failed to create AudioRecord")

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            throw IllegalStateException("AudioRecord is not initialised")
        }

        recorder.startRecording()

        audioThread = thread(
            start = true,
            name = "whisper_audio_capture"
        ) {
            val shortBuffer = ShortArray(1024)

            while (isRunning.get()) {
                val readCount = recorder.read(shortBuffer, 0, shortBuffer.size)

                if (readCount > 0) {
                    synchronized(bufferLock) {
                        for (i in 0 until readCount) {
                            audioBuffer.add(shortBuffer[i] / 32768.0f)
                        }

                        if (audioBuffer.size > windowSamples) {
                            val removeCount = audioBuffer.size - windowSamples
                            audioBuffer.subList(0, removeCount).clear()
                        }
                    }
                }
            }
        }
    }

    private fun startDecodeLoop(
        stepMs: Int,
        windowSamples: Int,
        minDecodeSamples: Int,
        language: String,
        audioCtx: Int
    ) {
        decodeThread = thread(
            start = true,
            name = "whisper_decode_loop"
        ) {
            while (isRunning.get()) {
                try {
                    Thread.sleep(stepMs.toLong())

                    val samples = synchronized(bufferLock) {
                        if (audioBuffer.size < minDecodeSamples) {
                            null
                        } else {
                            audioBuffer
                                .takeLast(windowSamples)
                                .toFloatArray()
                        }
                    }

                    if (samples == null || samples.isEmpty()) {
                        continue
                    }

                    val transcript = WhisperNative.transcribe(
                        contextPtr = contextPtr,
                        samples = samples,
                        language = language,
                        audioCtx = audioCtx
                    ).trim()

                    if (transcript.isNotEmpty() && transcript != lastTranscript) {
                        lastTranscript = transcript

                        eventCallback(
                            mapOf(
                                "type" to "transcript",
                                "text" to transcript
                            )
                        )
                    }
                } catch (e: InterruptedException) {
                    break
                } catch (e: Exception) {
                    eventCallback(
                        mapOf(
                            "type" to "error",
                            "message" to "Decode error: ${e.message}"
                        )
                    )
                }
            }
        }
    }

    fun stopStreaming() {
        if (!isRunning.get()) return

        isRunning.set(false)

        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }

        try {
            audioRecord?.release()
        } catch (_: Exception) {
        }

        audioRecord = null

        try {
            audioThread?.join(500)
        } catch (_: Exception) {
        }

        try {
            decodeThread?.join(500)
        } catch (_: Exception) {
        }

        audioThread = null
        decodeThread = null

        sendStatus("Audio capture stopped")
    }

    fun release() {
        stopStreaming()

        if (contextPtr != 0L) {
            WhisperNative.releaseContext(contextPtr)
            contextPtr = 0L
        }

        synchronized(bufferLock) {
            audioBuffer.clear()
        }

        sendStatus("Whisper resources released")
    }

    private fun sendStatus(message: String) {
        eventCallback(
            mapOf(
                "type" to "status",
                "message" to message
            )
        )
    }
}