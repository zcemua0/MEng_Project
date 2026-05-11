//Main screen
//From ble_connection_page.dart, navigates to offline_stt_page.dart after a placeholder BLE scan.
//Initialises the STT model, starts/stops offline transcription, receives transcript events, and displays the transcribed text.

//_transcribedText
//Stores the latest STT output as a normal Dart String for display in the app.

//_transcribedTextUtf8Bytes
//Stores the same STT output encoded as UTF-8 bytes. This is the variable that can later be sent over BLE to the Raspberry Pi and displayed on the OLED.
//await _bleService.sendTextBytesToGlasses(_transcribedTextUtf8Bytes);

import 'dart:async';

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/whisper_stt_service.dart';
import '../widgets/stt_control_button.dart';
import '../widgets/transcript_display.dart';

class OfflineSttPage extends StatefulWidget {
  const OfflineSttPage({super.key});

  @override
  State<OfflineSttPage> createState() => _OfflineSttPageState();
}

class _OfflineSttPageState extends State<OfflineSttPage> {
  final WhisperSttService _sttService = WhisperSttService();

  StreamSubscription<SttEvent>? _eventSubscription;

  bool _isInitialised = false;
  bool _isListening = false;
  bool _isBusy = false;

  String _status = 'Ready';
  String _transcribedText = '';

  // UTF-8 encoded version of the latest STT output.
  // This can later be sent over BLE to the Raspberry Pi / OLED.
  Uint8List _transcribedTextUtf8Bytes = Uint8List(0);

  @override
  void initState() {
    super.initState();
    _listenToNativeEvents();
    _initialiseStt();
  }

  void _listenToNativeEvents() {
    _eventSubscription = _sttService.events.listen(
      (event) {
        if (!mounted) return;

        setState(() {
          if (event.type == 'transcript') {
            final newText = event.message.trim();
          
            if (newText.isNotEmpty) {
              _transcribedText = newText;
            }

            // Convert the displayed transcript into UTF-8 bytes.
            // This is the variable to send over BLE later.
              _transcribedTextUtf8Bytes = Uint8List.fromList(
              utf8.encode(_transcribedText),
              );
          }
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _status = 'Native event error: $error';
        });
      },
    );
  }

  Future<void> _initialiseStt() async {
    setState(() {
      _isBusy = true;
      _status = 'Initialising STT model...';
    });

    try {
      await _sttService.initModel(
        assetPath: 'assets/models/ggml-tiny.en.bin',
        threads: 4,
      );

      if (!mounted) return;

      setState(() {
        _isInitialised = true;
        _status = 'STT model ready';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitialised = false;
        _status = 'STT init failed: $e';
      });
    } 
    finally {
    if (mounted) {
      setState(() {
        _isBusy = false;
      });
    }
  }  
  }

  Future<bool> _checkMicrophonePermission() async {
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return true;
    }

    setState(() {
      _status = 'Microphone permission denied';
    });

    return false;
  }

  Future<void> _toggleStt() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
    });

    try {
      if (_isListening) {
        await _sttService.stopStreaming();

        if (!mounted) return;

        setState(() {
          _isListening = false;
          _status = 'STT stopped';
        });
      } else {
        final hasPermission = await _checkMicrophonePermission();
        if (!hasPermission) return;

        if (!_isInitialised) {
          await _initialiseStt();
        }

        if (!_isInitialised) {
          return;
        }

        await _sttService.startStreaming(
          stepMs: 400, //Decode every -s
          windowMs: 5000, //Use the last -s of audio
          keepMs: 200,
          language: 'en',
          audioCtx: 512,
        );

        if (!mounted) return;

        setState(() {
          _isListening = true;
          _status = 'Listening...';
          _transcribedText = '';
          _transcribedTextUtf8Bytes = Uint8List(0);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'STT error: $e';
      });
    } 
    finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();

    if (_isListening) {
      _sttService.stopStreaming();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isListening
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline STT'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _status,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              SttControlButton(
                isListening: _isListening,
                isBusy: _isBusy,
                onPressed: _toggleStt,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TranscriptDisplay(
                  text: _transcribedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
