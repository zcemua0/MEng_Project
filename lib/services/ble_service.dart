class BleService {
  Future<void> scanForDevices() async {
    // TODO: Implement real BLE scanning later.
    //
    // Future BLE logic:
    // 1. Scan for Raspberry Pi / AR glasses BLE device.
    // 2. Show available devices on BLE connection page.
    // 3. Connect to selected device.
    // 4. Receive audio from BLE.
    // 5. Send transcribed text back to Raspberry Pi / OLED.

    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> connectToDevice(String deviceId) async {
    // TODO: Implement BLE connection later.
  }

  Future<void> disconnect() async {
    // TODO: Implement BLE disconnection later.
  }

  Future<void> sendTextToGlasses(String text) async {
    // TODO: Later send transcribed UTF-8 text to Raspberry Pi / OLED.
  }
}