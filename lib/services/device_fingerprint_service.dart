import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceFingerprintService {
  static const String _fingerprintKey = 'device_fingerprint_v2';
  
  /// Generate a unique browser fingerprint based on multiple characteristics
  static Future<String> getFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if fingerprint already exists in localStorage
    String? existingFingerprint = prefs.getString(_fingerprintKey);
    if (existingFingerprint != null && existingFingerprint.isNotEmpty) {
      return existingFingerprint;
    }
    
    // Generate new fingerprint
    String fingerprint = await _generateFingerprint();
    
    // Store for future use (persistence across sessions, not incognito)
    await prefs.setString(_fingerprintKey, fingerprint);
    
    return fingerprint;
  }
  
  /// Generate fingerprint from browser/device characteristics
  static Future<String> _generateFingerprint() async {
    List<String> components = [];
    
    if (kIsWeb) {
      // Web-specific fingerprinting
      components.addAll(await _getWebFingerprint());
    } else {
      // Mobile fingerprinting
      components.addAll(await _getMobileFingerprint());
    }
    
    // Combine all components and hash
    String combined = components.join('|');
    var bytes = utf8.encode(combined);
    var digest = sha256.convert(bytes);
    
    return digest.toString();
  }
  
  /// Get web browser fingerprint components
  static Future<List<String>> _getWebFingerprint() async {
    List<String> components = [];
    
    try {
      // For web, use WebBrowserInfo from device_info_plus
      final deviceInfo = DeviceInfoPlugin();
      final webInfo = await deviceInfo.webBrowserInfo;
      
      // Browser information
      components.add('user_agent:${webInfo.userAgent}');
      components.add('vendor:${webInfo.vendor}');
      components.add('platform:${webInfo.platform}');
      components.add('language:${webInfo.language}');
      components.add('languages:${webInfo.languages?.join(",")}');
      components.add('hardware_concurrency:${webInfo.hardwareConcurrency}');
      components.add('device_memory:${webInfo.deviceMemory}');
      components.add('max_touch_points:${webInfo.maxTouchPoints}');
      
      // Timezone
      final now = DateTime.now();
      components.add('timezone_offset:${now.timeZoneOffset.inMinutes}');
      
      // Add a stable random component based on stored value
      final prefs = await SharedPreferences.getInstance();
      String? randomSeed = prefs.getString('device_random_seed');
      if (randomSeed == null) {
        randomSeed = Random().nextInt(1000000).toString();
        await prefs.setString('device_random_seed', randomSeed);
      }
      components.add('seed:$randomSeed');
      
    } catch (e) {
      print('Error generating web fingerprint: $e');
      // Fallback to timestamp-based ID
      final prefs = await SharedPreferences.getInstance();
      String? fallbackId = prefs.getString('device_fallback_id');
      if (fallbackId == null) {
        fallbackId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
        await prefs.setString('device_fallback_id', fallbackId);
      }
      components.add('fallback:$fallbackId');
    }
    
    return components;
  }
  
  /// Get mobile device fingerprint components
  static Future<List<String>> _getMobileFingerprint() async {
    List<String> components = [];
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        components.add('model:${androidInfo.model}');
        components.add('manufacturer:${androidInfo.manufacturer}');
        components.add('brand:${androidInfo.brand}');
        components.add('device:${androidInfo.device}');
        components.add('android_id:${androidInfo.id}');
        components.add('sdk:${androidInfo.version.sdkInt}');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        components.add('model:${iosInfo.model}');
        components.add('name:${iosInfo.name}');
        components.add('system_name:${iosInfo.systemName}');
        components.add('system_version:${iosInfo.systemVersion}');
        components.add('identifier:${iosInfo.identifierForVendor}');
      }
    } catch (e) {
      print('Error generating mobile fingerprint: $e');
      components.add('error:$e');
    }
    
    return components;
  }
}
