import 'package:flutter/material.dart';
import '../services/ble_service.dart';
import 'offline_stt_page.dart';

class BleConnectionPage extends StatefulWidget {
  const BleConnectionPage({super.key});

  @override
  State<BleConnectionPage> createState() => _BleConnectionPageState();
}

class _BleConnectionPageState extends State<BleConnectionPage> {
  // Single shared instance — passed into OfflineSttPage
  final BleService _bleService = BleService();

  bool _isScanning = false;
  String _status = 'BLE not connected';

  Future<void> _scanPressed() async {
    setState(() {
      _isScanning = true;
      _status = 'Scanning for Raspberry Pi...';
    });

    try {
      final device = await _bleService.scanForDevices();

      if (!mounted) return;

      if (device == null) {
        setState(() {
          _isScanning = false;
          _status = 'No device found. Is the Pi running?';
        });
        return;
      }

      setState(() {
        _status = 'Found ${device.name}. Connecting...';
      });

      await _bleService.connectToDevice(device.id);

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _status = 'Connected to ${device.name}';
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          // Pass the connected BleService instance in
          builder: (_) => OfflineSttPage(bleService: _bleService),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... your existing build() — no changes needed here
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_audio, size: 72),
                  const SizedBox(height: 24),
                  Text('BLE Connection',
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(_status,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isScanning ? null : _scanPressed,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                      label:
                          Text(_isScanning ? 'Scanning...' : 'Scan for Pi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}