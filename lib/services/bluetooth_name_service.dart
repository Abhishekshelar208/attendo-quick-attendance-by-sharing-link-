import 'package:flutter/services.dart';

class BluetoothNameService {
  static const platform = MethodChannel('com.attendo/bluetooth');

  /// Set the Bluetooth device name
  /// Returns true if successful, false otherwise
  static Future<bool> setBluetoothName(String name) async {
    try {
      final bool result = await platform.invokeMethod('setBluetoothName', {'name': name});
      return result;
    } on PlatformException catch (e) {
      print("❌ Failed to set Bluetooth name: '${e.message}'");
      return false;
    }
  }

  /// Get the current Bluetooth device name
  static Future<String?> getBluetoothName() async {
    try {
      final String? name = await platform.invokeMethod('getBluetoothName');
      return name;
    } on PlatformException catch (e) {
      print("❌ Failed to get Bluetooth name: '${e.message}'");
      return null;
    }
  }
}
