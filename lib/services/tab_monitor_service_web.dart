import 'dart:async';
import 'dart:html' as html;
import 'package:firebase_database/firebase_database.dart';

class TabMonitorService {
  bool tabSwitched = false;
  int focusLostCount = 0;
  int totalFocusLossTime = 0;
  DateTime? _focusLostAt;
  bool isMonitoring = false;
  
  StreamSubscription? _visibilitySubscription;
  
  // Start monitoring for tab switches and focus loss
  void startMonitoring() {
    if (isMonitoring) return;
    
    isMonitoring = true;
    tabSwitched = false;
    focusLostCount = 0;
    totalFocusLossTime = 0;
    
    // Listen for visibility changes
    _visibilitySubscription = html.document.onVisibilityChange.listen((event) {
      if (html.document.hidden == true) {
        _onFocusLost();
      } else {
        _onFocusRegained();
      }
    });
    
    print('✅ Tab monitoring started (WEB)');
  }
  
  void _onFocusLost() {
    tabSwitched = true;
    focusLostCount++;
    _focusLostAt = DateTime.now();
    print('⚠️ Tab switched/minimized - Count: $focusLostCount');
  }
  
  void _onFocusRegained() {
    if (_focusLostAt != null) {
      int duration = DateTime.now().difference(_focusLostAt!).inSeconds;
      totalFocusLossTime += duration;
      print('✅ Focus regained - Lost for: ${duration}s, Total: ${totalFocusLossTime}s');
    }
  }
  
  // Stop monitoring
  void stopMonitoring() {
    _visibilitySubscription?.cancel();
    isMonitoring = false;
    print('🛑 Tab monitoring stopped');
  }
  
  // Get cheating flags
  Map<String, dynamic> getCheatingFlags() {
    return {
      'tabSwitched': tabSwitched,
      'focusLostCount': focusLostCount,
      'totalFocusLossTime': totalFocusLossTime,
      'severity': _getSeverity(),
    };
  }
  
  String _getSeverity() {
    if (focusLostCount == 0) return 'CLEAN';
    if (focusLostCount == 1 && totalFocusLossTime < 3) return 'LOW';
    if (focusLostCount <= 2 && totalFocusLossTime < 5) return 'MEDIUM';
    return 'HIGH';
  }
  
  // Report flags to Firebase
  Future<void> reportToFirebase(String sessionId, String rollNumber) async {
    if (!tabSwitched) return; // Nothing to report
    
    try {
      await FirebaseDatabase.instance
          .ref('attendance_sessions/$sessionId/cheating_flags/$rollNumber')
          .set({
        'tabSwitched': tabSwitched,
        'focusLostCount': focusLostCount,
        'totalFocusLossTime': totalFocusLossTime,
        'severity': _getSeverity(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('🚨 Cheating flags reported for Roll: $rollNumber');
    } catch (e) {
      print('❌ Error reporting flags: $e');
    }
  }
  
  void dispose() {
    stopMonitoring();
  }
}
