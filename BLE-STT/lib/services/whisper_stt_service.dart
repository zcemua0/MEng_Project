// Flutter bridge to native Android
// communication between Flutter and the native Android whisper.cpp code using MethodChannel and EventChannel. 
// It sends init/start/stop commands and receives STT events.

import 'package:flutter/services.dart';

class WhisperSttService {
  static const MethodChannel _methods = MethodChannel('offline_stt/methods');
  static const EventChannel _events = EventChannel('offline_stt/events');

  Stream<SttEvent> get events {
    return _events.receiveBroadcastStream().map(SttEvent.fromNativeEvent);
  }

  Future<void> initModel({
    required String assetPath,
    int threads = 4,
  }) async {
    await _methods.invokeMethod('initModel', {
      'assetPath': assetPath,
      'threads': threads,
    });
  }

  Future<void> startStreaming({
    int stepMs = 400,
    int windowMs = 5000,
    int keepMs = 200,
    String language = 'en',
    int audioCtx = 512,
  }) async {
    await _methods.invokeMethod('startStreaming', {
      'stepMs': stepMs,
      'windowMs': windowMs,
      'keepMs': keepMs,
      'language': language,
      'audioCtx': audioCtx,
    });
  }

  Future<void> stopStreaming() async {
    await _methods.invokeMethod('stopStreaming');
  }
}

class SttEvent {
  final String type;
  final String message;

  const SttEvent({
    required this.type,
    required this.message,
  });

  factory SttEvent.fromNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type']?.toString() ?? 'unknown';

      final message = (event['text'] ??
              event['message'] ??
              event['status'] ??
              event['error'] ??
              '')
          .toString();

      return SttEvent(
        type: type,
        message: message,
      );
    }

    return SttEvent(
      type: 'message',
      message: event?.toString() ?? '',
    );
  }
}