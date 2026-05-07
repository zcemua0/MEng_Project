// Kotlin declaration of the native C++ Whisper functions.
// Loads the whisper_jni library and exposes init, release,
// and transcribe functions to Kotlin.

package com.example.ble_stt

object WhisperNative {

    init {
        System.loadLibrary("whisper_jni")
    }

    external fun initContext(
        modelPath: String,
        threads: Int
    ): Long

    external fun releaseContext(
        contextPtr: Long
    )

    external fun transcribe(
        contextPtr: Long,
        samples: FloatArray,
        language: String,
        audioCtx: Int
    ): String
}