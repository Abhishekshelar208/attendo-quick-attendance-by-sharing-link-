import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

// Mobile stub - no tab monitoring on mobile
class TabMonitorService {
  bool tabSwitched = false;
  int focusLostCount = 0;
  int totalFocusLossTime = 0;
  bool isMonitoring = false;
  
  // No-op on mobile
  void startMonitoring() {
    isMonitoring = true;
    print('✅ Tab monitoring started (MOBILE - No-op)');
  }
  
  void stopMonitoring() {
    isMonitoring = false;
    print('🛑 Tab monitoring stopped (MOBILE)');
  }
  
  Map<String, dynamic> getCheatingFlags() {
    return {
      'tabSwitched': false,
      'focusLostCount': 0,
      'totalFocusLossTime': 0,
      'severity': 'CLEAN',
    };
  }
  
  Future<void> reportToFirebase(String sessionId, String rollNumber) async {
    // No-op on mobile
    print('ℹ️ Tab monitoring not available on mobile');
  }
  
  void dispose() {
    stopMonitoring();
  }
}
