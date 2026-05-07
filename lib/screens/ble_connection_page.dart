//Screen 1
//Shows the BLE Connection page and a Scan button

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import 'offline_stt_page.dart';

class BleConnectionPage extends StatefulWidget {
  const BleConnectionPage({super.key});

  @override
  State<BleConnectionPage> createState() => _BleConnectionPageState();
}

class _BleConnectionPageState extends State<BleConnectionPage> {
  final BleService _bleService = BleService();

  bool _isScanning = false;
  String _status = 'BLE not connected';

  Future<void> _scanPressed() async {
    setState(() {
      _isScanning = true;
      _status = 'Scanning for BLE devices...';
    });

    // Placeholder scan for now.
    // Later, real BLE scanning logic will be implemented inside ble_service.dart.
    await _bleService.scanForDevices();

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _status = 'Scan placeholder complete';
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OfflineSttPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(
                    Icons.bluetooth_audio,
                    size: 72,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'BLE Connection',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isScanning ? 'Scanning...' : 'Scan'),
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