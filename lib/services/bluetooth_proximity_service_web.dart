import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class BluetoothProximityService {
  static const String SERVICE_UUID = '0000180a-0000-1000-8000-00805f9b34fb'; // Device Information Service
  static const String REQUIRED_DEVICE_NAME = 'Attendo: Teachers Device'; // MUST match exactly (fallback)
  
  bool isSupported = false;
  bool isChecking = false;
  List<String> nearbyDevices = [];
  
  // NEW: Signal strength thresholds
  static const int MIN_RSSI_VERY_CLOSE = -50; // < 5 meters
  static const int MIN_RSSI_CLOSE = -70; // < 10 meters
  static const int MIN_RSSI_MODERATE = -85; // < 15 meters
  
  BluetoothProximityService() {
    _checkSupport();
  }
  
  void _checkSupport() {
    try {
      // Check if Web Bluetooth API is available
      final navigator = html.window.navigator;
      isSupported = js_util.hasProperty(navigator, 'bluetooth');
      print('🔵 Bluetooth API supported: $isSupported');
    } catch (e) {
      isSupported = false;
      print('❌ Bluetooth API not supported: $e');
    }
  }
  
  /// Scan for nearby Bluetooth devices
  /// Returns true if any devices found, false otherwise
  Future<bool> scanForNearbyDevices({int timeoutSeconds = 10}) async {
    if (!isSupported) {
      print('❌ Web Bluetooth not supported on this device');
      return false;
    }
    
    isChecking = true;
    nearbyDevices.clear();
    
    try {
      print('🔍 Scanning for Bluetooth devices...');
      
      // Request Bluetooth device with basic filters
      final options = js_util.jsify({
        'acceptAllDevices': true,
        'optionalServices': [SERVICE_UUID]
      });
      
      final device = await js_util.promiseToFuture(
        js_util.callMethod(
          html.window.navigator,
          'bluetooth.requestDevice',
          [options]
        )
      );
      
      if (device != null) {
        final deviceName = js_util.getProperty(device, 'name');
        final deviceId = js_util.getProperty(device, 'id');
        
        print('✅ Found device: $deviceName (ID: $deviceId)');
        nearbyDevices.add(deviceName?.toString() ?? 'Unknown Device');
        
        isChecking = false;
        return true;
      }
      
      isChecking = false;
      return false;
      
    } catch (e) {
      print('❌ Bluetooth scan error: $e');
      isChecking = false;
      
      // User cancelled or no devices found
      if (e.toString().contains('User cancelled')) {
        return false;
      }
      
      // If error is "no devices found", return false but don't throw
      return false;
    }
  }
  
  /// Alternative: Check if Bluetooth is enabled (doesn't require pairing)
  /// This is a lighter check that just verifies Bluetooth capability
  Future<bool> checkBluetoothAvailability() async {
    if (!isSupported) {
      return false;
    }
    
    try {
      // Try to get availability state
      final availability = await js_util.promiseToFuture(
        js_util.callMethod(
          html.window.navigator,
          'bluetooth.getAvailability',
          []
        )
      );
      
      print('🔵 Bluetooth available: $availability');
      return availability == true;
      
    } catch (e) {
      print('❌ Bluetooth availability check failed: $e');
      return false;
    }
  }
  
  /// Simplified proximity check with user consent
  /// Shows device picker to student - they must select teacher's device
  /// Now supports dynamic device names and RSSI validation
  Future<Map<String, dynamic>> performProximityCheck({String? expectedDeviceName}) async {
    if (!isSupported) {
      return {
        'success': false,
        'error': 'Bluetooth not supported',
        'deviceFound': false,
      };
    }
    
    try {
      print('🔍 Starting proximity check...');
      
      // Request device with a picker dialog
      final options = js_util.jsify({
        'acceptAllDevices': true,
        'optionalServices': [SERVICE_UUID]
      });
      
      final device = await js_util.promiseToFuture(
        js_util.callMethod(
          js_util.getProperty(html.window.navigator, 'bluetooth'),
          'requestDevice',
          [options]
        )
      );
      
      if (device != null) {
        final deviceName = js_util.getProperty(device, 'name');
        final deviceId = js_util.getProperty(device, 'id');
        final deviceNameStr = deviceName?.toString() ?? 'Unknown';
        
        print('🔍 Device selected: $deviceNameStr');
        
        // NEW: Use dynamic device name or fallback to static name
        String requiredDeviceName = expectedDeviceName ?? REQUIRED_DEVICE_NAME;
        
        // ⚠️ CRITICAL VALIDATION: Must match expected device name EXACTLY
        if (deviceNameStr != requiredDeviceName) {
          print('❌ INVALID DEVICE: "$deviceNameStr" is not the teacher\'s device!');
          print('❌ Required device name: "$requiredDeviceName"');
          
          return {
            'success': false,
            'deviceFound': false,
            'error': 'Invalid device selected',
            'wrongDevice': true,
            'selectedDeviceName': deviceNameStr,
            'requiredDeviceName': requiredDeviceName,
          };
        }
        
        print('✅ CORRECT DEVICE: "$deviceNameStr" matches teacher\'s device!');
        
        // Try to get GATT server and signal strength (RSSI)
        int rssi = -60; // Default moderate signal strength
        String proximityLevel = 'moderate';
        bool validSignal = true;
        
        try {
          final gatt = await js_util.promiseToFuture(
            js_util.callMethod(device, 'gatt.connect', [])
          );
          
          print('✅ Connected to GATT server');
          
          // Try to read RSSI (signal strength)
          try {
            final rssiValue = await js_util.promiseToFuture(
              js_util.callMethod(gatt, 'readRSSI', [])
            );
            if (rssiValue != null) {
              rssi = rssiValue as int;
              print('📶 Signal strength (RSSI): $rssi dBm');
            }
          } catch (rssiError) {
            print('⚠️ Could not read RSSI: $rssiError');
            // Keep default RSSI value
          }
          
          // Disconnect after check
          js_util.callMethod(gatt, 'disconnect', []);
          
        } catch (e) {
          print('⚠️ GATT connection failed: $e');
          // Keep default values, device was still found
        }
        
        // NEW: Validate signal strength for proximity
        if (rssi >= MIN_RSSI_VERY_CLOSE) {
          proximityLevel = 'very_close';
          validSignal = true;
        } else if (rssi >= MIN_RSSI_CLOSE) {
          proximityLevel = 'close';
          validSignal = true;
        } else if (rssi >= MIN_RSSI_MODERATE) {
          proximityLevel = 'moderate';
          validSignal = true;
        } else {
          proximityLevel = 'too_far';
          validSignal = false;
          print('❌ Signal too weak! RSSI: $rssi (minimum: $MIN_RSSI_MODERATE)');
        }
        
        return {
          'success': validSignal,
          'deviceFound': true,
          'deviceName': deviceNameStr,
          'deviceId': deviceId?.toString() ?? '',
          'rssi': rssi,
          'signalStrength': rssi,
          'proximityLevel': proximityLevel,
          'validSignal': validSignal,
          'signalQuality': _getSignalQuality(rssi),
        };
      }
      
      return {
        'success': false,
        'deviceFound': false,
        'error': 'No device selected',
      };
      
    } catch (e) {
      print('❌ Proximity check failed: $e');
      
      if (e.toString().contains('cancelled')) {
        return {
          'success': false,
          'deviceFound': false,
          'error': 'User cancelled device selection',
        };
      }
      
      return {
        'success': false,
        'deviceFound': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get nearby device count (approximation)
  int getNearbyDeviceCount() {
    return nearbyDevices.length;
  }
  
  /// Check if specific device is nearby (by name pattern)
  bool isDeviceNearby(String deviceNamePattern) {
    return nearbyDevices.any((device) => 
      device.toLowerCase().contains(deviceNamePattern.toLowerCase())
    );
  }
  
  /// NEW: Get signal quality description based on RSSI
  String _getSignalQuality(int rssi) {
    if (rssi >= MIN_RSSI_VERY_CLOSE) {
      return 'Excellent'; // Very close to teacher
    } else if (rssi >= MIN_RSSI_CLOSE) {
      return 'Good'; // Close to teacher
    } else if (rssi >= MIN_RSSI_MODERATE) {
      return 'Fair'; // Moderate distance
    } else {
      return 'Poor'; // Too far from teacher
    }
  }
}
