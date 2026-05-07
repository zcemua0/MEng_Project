// Main Android bridge between Flutter and native STT code.
// Receives Flutter MethodChannel calls, copies the Whisper model asset
// into Android internal storage, starts/stops the STT controller,
// and sends status/transcript/error events back to Flutter.

package com.example.ble_stt

import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val methodsChannelName = "offline_stt/methods"
    private val eventsChannelName = "offline_stt/events"

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var streamController: WhisperStreamController? = null
    private var modelPath: String? = null
    private var modelThreads: Int = 4

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventsChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodsChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initModel" -> handleInitModel(call, result)
                "startStreaming" -> handleStartStreaming(call, result)
                "stopStreaming" -> handleStopStreaming(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleInitModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val assetPath = call.argument<String>("assetPath")
                ?: throw IllegalArgumentException("Missing assetPath")

            val threads = call.argument<Int>("threads") ?: 4

            sendStatus("Copying model asset...")

            val copiedModelPath = copyFlutterAssetToFilesDir(assetPath)

            modelPath = copiedModelPath
            modelThreads = threads

            streamController?.release()
            streamController = WhisperStreamController(
                modelPath = copiedModelPath,
                threads = threads,
                eventCallback = { event -> sendEvent(event) }
            )

            streamController?.init()

            sendStatus("STT model ready")
            result.success(true)
        } catch (e: Exception) {
            sendError("Model init failed: ${e.message}")
            result.error("init_exception", e.message, null)
        }
    }

    private fun handleStartStreaming(call: MethodCall, result: MethodChannel.Result) {
        try {
            val controller = streamController
                ?: throw IllegalStateException("STT model has not been initialised")

            val stepMs = call.argument<Int>("stepMs") ?: 400
            val windowMs = call.argument<Int>("windowMs") ?: 5000
            val keepMs = call.argument<Int>("keepMs") ?: 200
            val language = call.argument<String>("language") ?: "en"
            val audioCtx = call.argument<Int>("audioCtx") ?: 512

            controller.startStreaming(
                stepMs = stepMs,
                windowMs = windowMs,
                keepMs = keepMs,
                language = language,
                audioCtx = audioCtx
            )

            sendStatus("Listening...")
            result.success(true)
        } catch (e: Exception) {
            sendError("Start streaming failed: ${e.message}")
            result.error("start_exception", e.message, null)
        }
    }

    private fun handleStopStreaming(result: MethodChannel.Result) {
        try {
            streamController?.stopStreaming()
            sendStatus("STT stopped")
            result.success(true)
        } catch (e: Exception) {
            sendError("Stop streaming failed: ${e.message}")
            result.error("stop_exception", e.message, null)
        }
    }

    private fun copyFlutterAssetToFilesDir(assetPath: String): String {
        val assetKey = FlutterInjector.instance()
            .flutterLoader()
            .getLookupKeyForAsset(assetPath)

        val fileName = assetPath.substringAfterLast("/")
        val outputFile = File(filesDir, fileName)

        if (outputFile.exists() && outputFile.length() > 0) {
            return outputFile.absolutePath
        }

        assets.open(assetKey).use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }

        return outputFile.absolutePath
    }

    private fun sendStatus(message: String) {
        sendEvent(
            mapOf(
                "type" to "status",
                "message" to message
            )
        )
    }

    private fun sendError(message: String) {
        sendEvent(
            mapOf(
                "type" to "error",
                "message" to message
            )
        )
    }

    private fun sendEvent(event: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    override fun onDestroy() {
        streamController?.release()
        streamController = null
        super.onDestroy()
    }
}