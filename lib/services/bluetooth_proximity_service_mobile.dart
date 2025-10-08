import 'dart:async';

/// Mobile stub - Bluetooth proximity not needed for mobile app
class BluetoothProximityService {
  bool isSupported = false;
  bool isChecking = false;
  List<String> nearbyDevices = [];
  
  BluetoothProximityService() {
    print('📱 Bluetooth proximity not used on mobile version');
  }
  
  Future<bool> scanForNearbyDevices({int timeoutSeconds = 10}) async {
    return true; // Always pass on mobile
  }
  
  Future<bool> checkBluetoothAvailability() async {
    return true; // Always pass on mobile
  }
  
  Future<Map<String, dynamic>> performProximityCheck() async {
    return {
      'success': true,
      'deviceFound': true,
      'deviceName': 'Mobile Device',
      'deviceId': 'mobile',
    };
  }
  
  int getNearbyDeviceCount() {
    return 0;
  }
  
  bool isDeviceNearby(String deviceNamePattern) {
    return true;
  }
}
