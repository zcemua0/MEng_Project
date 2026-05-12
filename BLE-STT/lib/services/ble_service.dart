import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleService {
  final _ble = FlutterReactiveBle();

  // These UUIDs must exactly match what you configure on the Raspberry Pi
  static final _serviceUuid =
      Uuid.parse('12345678-1234-1234-1234-123456789012');
  static final _characteristicUuid =
      Uuid.parse('12345678-1234-1234-1234-123456789013');

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;

  String? _connectedDeviceId;
  QualifiedCharacteristic? _txCharacteristic;

  // Called by BleConnectionPage when Scan is pressed
  Future<DiscoveredDevice?> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<DiscoveredDevice?>();

    _scanSubscription?.cancel();
    _scanSubscription = _ble
        .scanForDevices(withServices: [_serviceUuid])
        .timeout(timeout, onTimeout: (sink) => sink.close())
        .listen(
      (device) {
        if (!completer.isCompleted) {
          _scanSubscription?.cancel();
          completer.complete(device); // returns first matching device found
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    return completer.future;
  }

  // Call this after scanForDevices returns a device
  Future<void> connectToDevice(String deviceId) async {
    _connectionSubscription?.cancel();
    final completer = Completer<void>();

    _connectionSubscription = _ble
        .connectToDevice(id: deviceId)
        .listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _connectedDeviceId = deviceId;
        _txCharacteristic = QualifiedCharacteristic(
          serviceId: _serviceUuid,
          characteristicId: _characteristicUuid,
          deviceId: deviceId,
        );
        if (!completer.isCompleted) completer.complete();
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _connectedDeviceId = null;
        _txCharacteristic = null;
      }
    });

    return completer.future;
  }

  Future<void> disconnect() async {
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _connectedDeviceId = null;
    _txCharacteristic = null;
  }

  // Called by OfflineSttPage every time new transcript text arrives
  Future<void> sendTextToGlasses(String text) async {
    if (_txCharacteristic == null) return; // not connected, silently skip

    final bytes = utf8.encode(text); // UTF-8 encode

    // Chunk into 20-byte packets (default BLE MTU)
    const chunkSize = 20;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final chunk = bytes.sublist(i, min(i + chunkSize, bytes.length));
      await _ble.writeCharacteristicWithoutResponse(
        _txCharacteristic!,
        value: chunk,
      );
    }
  }

  bool get isConnected => _connectedDeviceId != null;
}