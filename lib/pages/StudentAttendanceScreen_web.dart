import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'package:attendo/services/tab_monitor_service.dart';
import 'package:attendo/services/bluetooth_proximity_service.dart';
import 'dart:async';
import 'StudentViewAttendanceScreen.dart';
import 'package:lottie/lottie.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String sessionId;

  StudentAttendanceScreen({required this.sessionId});

  @override
  _StudentAttendanceScreenState createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final TextEditingController _rollNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TabMonitorService _tabMonitor = TabMonitorService();
  final BluetoothProximityService _bluetoothService = BluetoothProximityService();
  
  String? lectureName;
  String? inputType;
  String? year;
  String? branch;
  String? date;
  String? time;
  String? serverOtp;
  bool isEnded = false;
  bool otpActive = false;
  bool bluetoothEnabled = true; // NEW: Whether Bluetooth is required for this session
  String? expectedDeviceName; // NEW: Dynamic device name from Firebase
  int otpDuration = 20; // Will be fetched from Firebase
  List<String> markedStudents = []; // List of students who marked attendance
  
  // Screen states
  // UPDATED FLOW: 1: Roll entry, 2: OTP waiting, 3: OTP entry, 4: Bluetooth check (if enabled)
  int currentStep = 1;
  bool isSubmitting = false;
  bool isCheckingBluetooth = false;
  bool bluetoothCheckPassed = false;
  String? bluetoothDeviceName;
  
  // Timer
  int remainingSeconds = 20;
  Timer? _otpTimer;
  Timer? _sessionListener;
  DateTime? otpActivatedAt;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _otpController.dispose();
    _otpTimer?.cancel();
    _sessionListener?.cancel();
    _tabMonitor.dispose();
    super.dispose();
  }

  bool _isInitialLoading = true; // Track initial load

  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}");

    sessionRef.once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['subject'];
          inputType = data['type'];
          year = data['year'];
          branch = data['branch'];
          date = data['date'];
          time = data['time'];
          serverOtp = data['otp'];
          isEnded = data['is_ended'] ?? false;
          bluetoothEnabled = data['bluetooth_enabled'] ?? true; // NEW: Get Bluetooth setting
          expectedDeviceName = data['bluetooth_device_name']; // NEW: Get dynamic device name
          otpDuration = data['otp_duration'] ?? 20; // Get custom duration
          _isInitialLoading = false; // Mark loading as complete
          
          // If session ended, fetch the attendance list
          if (isEnded && data['students'] != null) {
            Map<dynamic, dynamic> studentsMap = data['students'] as Map<dynamic, dynamic>;
            List<String> students = studentsMap.values.map((e) => e['entry'].toString()).toList();
            
            // Sort in ascending order
            students.sort((a, b) {
              final aNum = int.tryParse(a);
              final bNum = int.tryParse(b);
              if (aNum != null && bNum != null) {
                return aNum.compareTo(bNum);
              }
              return a.compareTo(b);
            });
            
            markedStudents = students;
          }
        });
      }
    });
  }


  void _startListeningForOTPActivation() {
    DatabaseReference sessionRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}");

    // Start tab monitoring when student is on OTP waiting screen
    _tabMonitor.startMonitoring();

    _sessionListener?.cancel();
    _sessionListener = Timer.periodic(Duration(seconds: 1), (timer) async {
      final snapshot = await sessionRef.once();
      final data = snapshot.snapshot.value as Map?;
      
      if (data != null) {
        bool active = data['otp_active'] ?? false;
        
        if (active && !otpActive) {
          // OTP just got activated!
          int duration = data['otp_duration'] ?? 20; // Get custom duration
          setState(() {
            otpActive = true;
            currentStep = 3; // Move to OTP entry (step 3 now)
            remainingSeconds = duration;
            otpDuration = duration;
            otpActivatedAt = DateTime.now();
          });
          
          // Start countdown
          _startOTPCountdown();
          
          print('🔥 OTP ACTIVATED! Students can now enter OTP');
        }
        
        if (data['is_ended'] == true) {
          timer.cancel();
        }
      }
    });
  }

  void _startOTPCountdown() {
    _otpTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleOTPTimeout();
      }
    });
  }

  void _handleOTPTimeout() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Time\'s up! OTP window closed.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> submitAttendance() async {

    setState(() {
      isSubmitting = true;
    });

    String enteredValue = _rollNumberController.text.trim();
    final deviceId = await DeviceFingerprintService.getFingerprint();

    try {
      // Check for duplicate roll number
      DatabaseReference dbRef = FirebaseDatabase.instance
          .ref()
          .child("attendance_sessions/${widget.sessionId}/students");

      DatabaseEvent event = await dbRef.once();

      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> existingEntries = studentsMap.values.map((e) => e['entry'].toString()).toList();

        if (existingEntries.contains(enteredValue)) {
          setState(() {
            isSubmitting = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("This $inputType is already marked!"),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Calculate submission time
      int submissionTime = otpActivatedAt != null 
          ? DateTime.now().difference(otpActivatedAt!).inSeconds 
          : 0;

      // Add new attendance entry
      String studentId = dbRef.push().key!;
      await dbRef.child(studentId).set({
        'entry': enteredValue,
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        'otp_verified': true,
        'submission_time_seconds': submissionTime,
        'bluetooth_verified': bluetoothCheckPassed,
        'bluetooth_device': bluetoothDeviceName ?? 'N/A',
      });
      
      // NEW: Record connected device for duplicate detection
      if (bluetoothCheckPassed && bluetoothDeviceName != null && bluetoothDeviceName != 'N/A') {
        await FirebaseDatabase.instance
            .ref()
            .child("attendance_sessions/${widget.sessionId}/connected_devices")
            .push()
            .set({
              'device_name': bluetoothDeviceName,
              'student_entry': enteredValue,
              'timestamp': DateTime.now().toIso8601String(),
            });
      }

      // Report cheating flags
      await _tabMonitor.reportToFirebase(widget.sessionId, enteredValue);

      // Store in localStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('attendance_${widget.sessionId}', enteredValue);

      setState(() {
        isSubmitting = false;
      });

      // Navigate to confirmation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentViewAttendanceScreen(
            sessionId: widget.sessionId,
            markedEntry: enteredValue,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      
      print('Error submitting attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting attendance. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading animation during initial load
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Lottie.asset(
            'lib/assets/animations/runningcuteanimation.json',
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            "Mark Attendance",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
        ),
        body: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (isEnded) {
      return _buildSessionEndedView();
    }

    switch (currentStep) {
      case 1:
        return _buildRollNumberEntry(); // Step 1: Roll Number
      case 2:
        return _buildOTPWaitingScreen(); // Step 2: Wait for OTP
      case 3:
        return _buildOTPEntryScreen(); // Step 3: Enter OTP
      case 4:
        return _buildBluetoothCheckScreen(); // Step 4: Bluetooth Check (if enabled)
      default:
        return _buildRollNumberEntry();
    }
  }

  Future<void> _performInitialBluetoothCheck() async {
    // This is for Step 1 - initial proximity verification
    setState(() {
      isCheckingBluetooth = true;
    });

    try {
      final result = await _bluetoothService.performProximityCheck();
      
      setState(() {
        isCheckingBluetooth = false;
        bluetoothCheckPassed = result['success'] == true;
        bluetoothDeviceName = result['deviceName'];
      });

      if (bluetoothCheckPassed) {
        print('✅ Initial Bluetooth check passed: ${result['deviceName']}');
        // Success message shown in UI, user clicks Continue button
      } else {
        // Check if wrong device was selected
        if (result['wrongDevice'] == true) {
          String selectedDevice = result['selectedDeviceName'] ?? 'Unknown';
          String requiredDevice = result['requiredDeviceName'] ?? 'Attendo: Teachers Device';
          
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Wrong Device!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You selected:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '❌ "$selectedDevice"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You must connect to:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '✅ "$requiredDevice"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '⚠️ You can only mark attendance by connecting to your teacher\'s device.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.poppins(
                        color: ThemeHelper.getPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Could not detect teacher\'s device: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isCheckingBluetooth = false;
        bluetoothCheckPassed = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Bluetooth error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performBluetoothCheck() async {
    // Validate OTP first
    if (_otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_otpController.text.trim() != serverOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Incorrect OTP!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check session status - NEW: Block OTP entry if time expired
    DatabaseReference sessionRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}");
    final snapshot = await sessionRef.once();
    final data = snapshot.snapshot.value as Map?;
    
    if (data != null) {
      String sessionStatus = data['session_status'] ?? 'active';
      if (sessionStatus == 'time_expired') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Time expired! The teacher has closed the OTP window.\nPlease wait for the next OTP activation.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      if (sessionStatus == 'ended') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Session has been ended by the teacher.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Check timing
    if (otpActivatedAt != null) {
      int elapsedSeconds = DateTime.now().difference(otpActivatedAt!).inSeconds;
      if (elapsedSeconds > otpDuration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏰ Too late! Submission time exceeded.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check if Bluetooth is enabled for this session
    if (!bluetoothEnabled) {
      // Bluetooth disabled - skip Bluetooth check and submit directly
      print('📱 Bluetooth disabled for this session - submitting attendance directly');
      
      setState(() {
        isSubmitting = true;
        bluetoothCheckPassed = true; // Mark as passed since it's not required
        bluetoothDeviceName = 'N/A (Bluetooth disabled)';
      });
      
      // Submit attendance directly
      await submitAttendance();
      return;
    }

    // Bluetooth enabled - proceed with proximity check
    setState(() {
      currentStep = 4;
      isCheckingBluetooth = true;
    });

    // Perform Bluetooth check with dynamic device name
    try {
      final result = await _bluetoothService.performProximityCheck(
        expectedDeviceName: expectedDeviceName, // Pass dynamic device name
      );
      
      setState(() {
        isCheckingBluetooth = false;
        bluetoothCheckPassed = result['success'] == true;
        bluetoothDeviceName = result['deviceName'];
      });

      if (bluetoothCheckPassed) {
        String signalQuality = result['signalQuality'] ?? 'Good';
        int rssi = result['rssi'] ?? -60;
        print('✅ Bluetooth check passed: ${result['deviceName']} (Signal: $signalQuality, RSSI: $rssi)');
        
        // Show signal strength feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected successfully! Signal: $signalQuality'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Auto-submit after successful Bluetooth check
        Future.delayed(Duration(milliseconds: 800), () {
          submitAttendance();
        });
      } else {
        // Check if signal is too weak
        if (result['validSignal'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📶 Signal too weak! Move closer to the teacher and try again.\nRSSI: ${result['rssi']} (min: -85)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }
        
        // Check if wrong device was selected
        if (result['wrongDevice'] == true) {
          String selectedDevice = result['selectedDeviceName'] ?? 'Unknown';
          String requiredDevice = result['requiredDeviceName'] ?? 'Attendo: Teachers Device';
          
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Wrong Device!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You connected to the wrong device:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '❌ "$selectedDevice"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '❌ ATTENDANCE NOT MARKED',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You must connect to:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '✅ "$requiredDevice"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠️ You can only mark attendance by connecting to your teacher\'s device. Please try again with the correct device.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Stay at Bluetooth check step to retry
                      setState(() {
                        isCheckingBluetooth = false;
                        bluetoothCheckPassed = false;
                      });
                    },
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.poppins(
                        color: ThemeHelper.getPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Bluetooth check failed: ${result['error']}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isCheckingBluetooth = false;
        bluetoothCheckPassed = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Bluetooth error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRollNumberEntry() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Session Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ThemeHelper.getPrimaryGradient(context),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Session Info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: ThemeHelper.getPrimaryGradient(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    lectureName ?? "Loading...",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (year != null && branch != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$year • $branch',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Input Card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getShadowColor(context),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: ThemeHelper.getPrimaryColor(context),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Enter Your Details',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step 1 of ${bluetoothEnabled ? '4' : '3'}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Input Field
                  TextField(
                    controller: _rollNumberController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: inputType ?? 'Roll Number',
                      hintText: 'Enter your ${inputType ?? 'Roll Number'}',
                      prefixIcon: Icon(
                        inputType == "Roll Number" ? Icons.tag_rounded : Icons.person_rounded,
                        color: ThemeHelper.getPrimaryColor(context),
                        size: 24,
                      ),
                      filled: true,
                      fillColor: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: ThemeHelper.getBorderColor(context),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: ThemeHelper.getPrimaryColor(context),
                          width: 2,
                        ),
                      ),
                      labelStyle: GoogleFonts.poppins(
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      hintStyle: GoogleFonts.poppins(
                        color: ThemeHelper.getTextTertiary(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                    ),
                    keyboardType: inputType == "Roll Number"
                        ? TextInputType.number
                        : TextInputType.text,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 28),
                  
                  // Next Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_rollNumberController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please enter your ${inputType ?? 'Roll Number'}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Move directly to OTP waiting screen
                        setState(() {
                          currentStep = 2; // OTP waiting is step 2 now
                        });
                        
                        // Start listening for OTP activation
                        _startListeningForOTPActivation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeHelper.getPrimaryColor(context),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildOTPWaitingScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            // Student Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ThemeHelper.getPrimaryGradient(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Roll Number',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _rollNumberController.text,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // Waiting Animation
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getShadowColor(context),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '⏳ Waiting for OTP...',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Teacher will announce the OTP code soon',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            Spacer(),
            
            // Warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ Do NOT switch tabs or minimize!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPEntryScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Timer Circle
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: remainingSeconds > 10 
                      ? [Colors.green, Colors.green.shade700]
                      : [Colors.red, Colors.red.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (remainingSeconds > 10 ? Colors.green : Colors.red)
                        .withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$remainingSeconds',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'seconds remaining',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: ThemeHelper.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 40),
            
            // OTP Input Card
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lock_open_rounded,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Enter OTP Code',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Listen to your teacher for the code',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Attendance Mode Indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bluetoothEnabled 
                          ? Colors.blue.withOpacity(0.1) 
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: bluetoothEnabled 
                            ? Colors.blue.withOpacity(0.3) 
                            : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bluetoothEnabled 
                              ? Icons.security_rounded 
                              : Icons.wifi_rounded,
                          color: bluetoothEnabled 
                              ? Colors.blue 
                              : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bluetoothEnabled 
                              ? 'High Security: Bluetooth verification required' 
                              : 'Remote Mode: No proximity check needed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: bluetoothEnabled 
                                ? Colors.blue.shade700 
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // OTP Input
                  TextField(
                    controller: _otpController,
                    autofocus: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: '----',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 32,
                        letterSpacing: 12,
                        color: ThemeHelper.getTextTertiary(context),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.green.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      // No auto-submit. Web Bluetooth requires an explicit user gesture,
                      // so we ask the student to press the button below.
                    },
                  ),
                  const SizedBox(height: 28),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _performBluetoothCheck,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: isSubmitting
                          ? CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  bluetoothEnabled 
                                      ? Icons.bluetooth_rounded 
                                      : Icons.check_circle_rounded, 
                                  size: 28
                                ),
                                SizedBox(width: 12),
                                Text(
                                  bluetoothEnabled 
                                      ? 'Continue to Bluetooth Check' 
                                      : 'Submit Attendance',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            Spacer(),
            
            // Warnings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Tab monitoring active',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Any tab switch will be reported to teacher',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionEndedView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Session Ended Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeHelper.getWarningColor(context),
                      ThemeHelper.getWarningColor(context).withValues(alpha: 0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Session Ended Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Session Ended',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This attendance session has been closed by the teacher',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Session Details Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getShadowColor(context),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (lectureName != null) ...[
                    _buildDetailRow(Icons.book_rounded, 'Lecture', lectureName!),
                    const SizedBox(height: 16),
                  ],
                  if (year != null && branch != null) ...[
                    _buildDetailRow(Icons.school_rounded, 'Class', '$year - $branch'),
                    const SizedBox(height: 16),
                  ],
                  if (date != null) ...[
                    _buildDetailRow(Icons.calendar_today_rounded, 'Date', date!),
                    const SizedBox(height: 16),
                  ],
                  if (time != null) ...[
                    _buildDetailRow(Icons.access_time_rounded, 'Time', time!),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailRow(
                    Icons.people_rounded,
                    'Total Present',
                    '${markedStudents.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Present Students Section
            Text(
              'Present Students',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getShadowColor(context),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: markedStudents.isEmpty
                  ? Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No students marked attendance',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Total: ${markedStudents.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getSuccessColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Students List
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: markedStudents.map((rollNo) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: ThemeHelper.getSuccessColor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    rollNo,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothCheckScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Session Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ThemeHelper.getPrimaryGradient(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    lectureName ?? 'Loading...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (year != null && branch != null) ...[
                    SizedBox(height: 8),
                    Text(
                      '$year • $branch',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            if (isCheckingBluetooth) ...[
              // Checking state
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getShadowColor(context),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth_searching_rounded,
                        size: 64,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '🔍 Scanning for devices...',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Look for this device:',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '"Attendo: Teachers Device"',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CircularProgressIndicator(
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ] else if (bluetoothCheckPassed) ...[
              // Success state
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth_connected_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '✅ Device Found!',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        bluetoothDeviceName ?? 'Unknown Device',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '✅ Proximity verified!',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Submitting your attendance...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Initial/Failed state - Show "Check Proximity" button
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getShadowColor(context),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth_rounded,
                        size: 64,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '📡 Proximity Check Required',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Final verification step:\nConnect to teacher\'s Bluetooth device to confirm you\'re in the classroom.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.getTextSecondary(context),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ℹ️ If permission blocked: Click lock icon in address bar → Reset permissions',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Retry Bluetooth check (Step 5 - Final check)
                          setState(() {
                            isCheckingBluetooth = true;
                          });
                          
                          try {
                            final result = await _bluetoothService.performProximityCheck();
                            
                            setState(() {
                              isCheckingBluetooth = false;
                              bluetoothCheckPassed = result['success'] == true;
                              bluetoothDeviceName = result['deviceName'];
                            });

                            if (bluetoothCheckPassed) {
                              // Auto-submit after successful check
                              Future.delayed(Duration(milliseconds: 800), () {
                                submitAttendance();
                              });
                            } else {
                              // Show error dialog if wrong device
                              if (result['wrongDevice'] == true) {
                                String selectedDevice = result['selectedDeviceName'] ?? 'Unknown';
                                String requiredDevice = result['requiredDeviceName'] ?? 'Attendo: Teachers Device';
                                
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red, size: 28),
                                          SizedBox(width: 12),
                                          Text(
                                            'Wrong Device!',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'You selected:',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '❌ "$selectedDevice"',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'You must connect to:',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '✅ "$requiredDevice"',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            '⚠️ You can only mark attendance by connecting to your teacher\'s device.',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text(
                                            'Try Again',
                                            style: GoogleFonts.poppins(
                                              color: ThemeHelper.getPrimaryColor(context),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Could not detect teacher\'s device: ${result['error']}'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setState(() {
                              isCheckingBluetooth = false;
                              bluetoothCheckPassed = false;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ Bluetooth error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_rounded, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Check Proximity',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Info card - Required device name
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bluetooth_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Look for this device name:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Text(
                      '"Attendo: Teachers Device"',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This verifies you are physically present in the classroom',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: ThemeHelper.getPrimaryColor(context),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: ThemeHelper.getTextSecondary(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: ThemeHelper.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
