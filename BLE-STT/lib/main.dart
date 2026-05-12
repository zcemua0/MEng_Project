//Starts the Flutter app, sets the app theme, and opens the first page: BLEConnectionPage.

import 'package:flutter/material.dart';

import 'screens/ble_connection_page.dart';

void main() {
  runApp(const BleSttApp());
}

class BleSttApp extends StatelessWidget {
  const BleSttApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE STT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const BleConnectionPage(),
    );
  }
}