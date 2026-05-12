#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <unordered_map>

#include <android/log.h>

#include "whisper.h"

#define LOG_TAG "whisper_jni"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static std::mutex g_contextMutex;
static std::unordered_map<whisper_context *, int> g_contextThreads;

static std::string jstringToString(JNIEnv *env, jstring input) {
    if (input == nullptr) {
        return "";
    }

    const char *chars = env->GetStringUTFChars(input, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(input, chars);

    return result;
}

extern "C"
JNIEXPORT jlong JNICALL
Java_com_example_ble_1stt_WhisperNative_initContext(
        JNIEnv *env,
        jobject /* thisObject */,
        jstring modelPath,
        jint threads
) {
    const std::string path = jstringToString(env, modelPath);

    LOGI("Initialising whisper context with model: %s", path.c_str());

    whisper_context_params contextParams = whisper_context_default_params();

    whisper_context *ctx = whisper_init_from_file_with_params(
            path.c_str(),
            contextParams
    );

    if (ctx == nullptr) {
        LOGE("Failed to initialise whisper context");
        return 0;
    }

    {
        std::lock_guard<std::mutex> lock(g_contextMutex);
        g_contextThreads[ctx] = threads > 0 ? threads : 4;
    }

    LOGI("Whisper context initialised successfully");

    return reinterpret_cast<jlong>(ctx);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_ble_1stt_WhisperNative_releaseContext(
        JNIEnv * /* env */,
        jobject /* thisObject */,
        jlong contextPtr
) {
    auto *ctx = reinterpret_cast<whisper_context *>(contextPtr);

    if (ctx == nullptr) {
        return;
    }

    {
        std::lock_guard<std::mutex> lock(g_contextMutex);
        g_contextThreads.erase(ctx);
    }

    whisper_free(ctx);

    LOGI("Whisper context released");
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_ble_1stt_WhisperNative_transcribe(
        JNIEnv *env,
        jobject /* thisObject */,
        jlong contextPtr,
        jfloatArray samplesArray,
        jstring languageString,
        jint audioCtx
) {
    auto *ctx = reinterpret_cast<whisper_context *>(contextPtr);

    if (ctx == nullptr) {
        return env->NewStringUTF("");
    }

    const jsize sampleCount = env->GetArrayLength(samplesArray);

    if (sampleCount <= 0) {
        return env->NewStringUTF("");
    }

    std::vector<float> samples(sampleCount);
    env->GetFloatArrayRegion(samplesArray, 0, sampleCount, samples.data());

    const std::string language = jstringToString(env, languageString);

    int threads = 4;
    {
        std::lock_guard<std::mutex> lock(g_contextMutex);
        auto it = g_contextThreads.find(ctx);
        if (it != g_contextThreads.end()) {
            threads = it->second;
        }
    }

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);

    params.n_threads = threads;
    params.language = language.empty() ? "en" : language.c_str();

    params.translate = false;

    params.no_context = true;
    params.single_segment = true;
    params.no_timestamps = true;
    params.suppress_blank = true;

    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;

    if (audioCtx > 0) {
        params.audio_ctx = audioCtx;
    }

    const int result = whisper_full(
            ctx,
            params,
            samples.data(),
            static_cast<int>(samples.size())
    );

    if (result != 0) {
        LOGE("whisper_full failed with code: %d", result);
        return env->NewStringUTF("");
    }

    std::string transcript;

    const int segmentCount = whisper_full_n_segments(ctx);

    for (int i = 0; i < segmentCount; ++i) {
        const char *segmentText = whisper_full_get_segment_text(ctx, i);

        if (segmentText != nullptr) {
            transcript += segmentText;
        }
    }

    return env->NewStringUTF(transcript.c_str());
}