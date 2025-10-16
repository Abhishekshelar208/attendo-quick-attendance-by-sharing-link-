import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendo/services/bluetooth_name_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ShareAttendanceScreen extends StatefulWidget {
  final String sessionId;

  ShareAttendanceScreen({required this.sessionId});

  @override
  _ShareAttendanceScreenState createState() => _ShareAttendanceScreenState();
}

class _ShareAttendanceScreenState extends State<ShareAttendanceScreen> {
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref();
  List<String> markedStudents = [];
  Map<String, dynamic> cheatingFlags = {};
  String? lectureName;
  String? year;
  String? branch;
  String? otp;
  bool isEnded = false;
  bool otpActive = false;
  bool bluetoothActive = false; // NEW: Track Bluetooth status
  bool bluetoothEnabled = true; // NEW: Whether Bluetooth is enabled for this session
  String sessionStatus = 'active'; // NEW: Track session status (active, time_expired, ended)
  String? dynamicDeviceName; // NEW: Session-specific device name
  List<String> connectedDevices = []; // NEW: Track connected devices
  int timerSeconds = 20;
  int selectedDuration = 20; // Default 20 seconds
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generateSessionDeviceName();
    _fetchSessionDetails();
    _listenForAttendanceUpdates();
    _listenForCheatingFlags();
    _listenForConnectedDevices(); // NEW: Listen for connected devices
  }
  
  void _generateSessionDeviceName() {
    // Generate session-specific device name
    DateTime now = DateTime.now();
    String dateStr = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}';
    
    // Use session ID or subject for uniqueness
    String sessionPart = widget.sessionId.length > 6 
        ? widget.sessionId.substring(widget.sessionId.length - 6) 
        : widget.sessionId;
    
    dynamicDeviceName = 'Attendo-$sessionPart-$dateStr';
    print('📱 Generated device name: $dynamicDeviceName');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = _attendanceRef.child("attendance_sessions/${widget.sessionId}");
    sessionRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['subject'];
          year = data['year'];
          branch = data['branch'];
          otp = data['otp'];
          isEnded = data['is_ended'] ?? false;
          otpActive = data['otp_active'] ?? false;
          bluetoothActive = data['bluetooth_active'] ?? false;
          bluetoothEnabled = data['bluetooth_enabled'] ?? true; // NEW: Fetch Bluetooth toggle
          sessionStatus = data['session_status'] ?? 'active'; // NEW: Fetch session status
        });
      }
    });
  }

  void _listenForAttendanceUpdates() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/students").onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> updatedStudents = studentsMap.values.map((e) => e['entry'].toString()).toList();

        updatedStudents.sort((a, b) {
          final aNum = int.tryParse(a);
          final bNum = int.tryParse(b);
          if (aNum != null && bNum != null) {
            return aNum.compareTo(bNum);
          }
          return a.compareTo(b);
        });

        setState(() {
          markedStudents = updatedStudents;
        });
      }
    });
  }

  void _listenForCheatingFlags() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/cheating_flags").onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          cheatingFlags = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });
  }
  
  void _listenForConnectedDevices() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/connected_devices").onValue.listen((event) {
      if (event.snapshot.value != null) {
        List<String> devices = (event.snapshot.value as List).cast<String>();
        setState(() {
          connectedDevices = devices;
        });
        
        // Check for duplicates
        _checkForDuplicateDevices(devices);
      }
    });
  }
  
  void _checkForDuplicateDevices(List<String> devices) {
    Map<String, int> deviceCount = {};
    for (String device in devices) {
      deviceCount[device] = (deviceCount[device] ?? 0) + 1;
    }
    
    List<String> duplicates = deviceCount.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();
    
    if (duplicates.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Duplicate devices detected: ${duplicates.join(", ")}\nPossible spoofing attempt!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 6),
          action: SnackBarAction(
            label: 'View Details',
            onPressed: () => _showDuplicateDevicesDialog(duplicates),
          ),
        ),
      );
    }
  }
  
  void _showDuplicateDevicesDialog(List<String> duplicates) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'Duplicate Devices',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Multiple devices with the same name detected:',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              SizedBox(height: 12),
              ...duplicates.map((device) => Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚠️ "$device"',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
              SizedBox(height: 12),
              Text(
                'This might indicate students attempting to spoof your device name.',
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
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  void activateOTP() async {
    setState(() {
      otpActive = true;
      timerSeconds = selectedDuration;
    });

    // NEW: Auto-enable Bluetooth when OTP is activated (Time Window feature)
    if (bluetoothEnabled && !bluetoothActive) {
      print('🟢 Auto-enabling Bluetooth due to OTP activation');
      activateBluetooth(); // Remove await since it's a void function
    }

    // Update Firebase
    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'otp_active': true,
      'otp_start_time': DateTime.now().toIso8601String(),
      'otp_duration': selectedDuration,
      'session_status': 'active', // NEW: Reset to active when OTP is reactivated
    });

    // Start countdown
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timerSeconds > 0) {
        setState(() {
          timerSeconds--;
        });
      } else {
        // Timer expired - block student OTP entry but keep session open for teacher
        _handleTimerExpiry();
        timer.cancel();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP activated! Students have $selectedDuration seconds\n🟢 Bluetooth broadcasting started automatically'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _handleTimerExpiry() async {
    setState(() {
      otpActive = false;
    });

    // NEW: Auto-disable Bluetooth when OTP expires (Time Window feature)
    if (bluetoothActive) {
      print('🔴 Auto-disabling Bluetooth due to OTP expiry');
      deactivateBluetooth(); // Remove await since it's a void function
    }

    // End the session automatically when timer expires
    endAttendance(); // Remove await since it's a void function

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⏰ Time expired! Session ended automatically.\n🔴 Bluetooth broadcasting stopped.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );
  }

  void deactivateOTP() async {
    setState(() {
      otpActive = false;
    });

    _timer?.cancel();

    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'otp_active': false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OTP window closed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showTimerSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int customSeconds = selectedDuration;
        return AlertDialog(
          title: Text(
            'Select OTP Duration',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('10 seconds', style: GoogleFonts.poppins()),
                leading: Radio<int>(
                  value: 10,
                  groupValue: customSeconds,
                  onChanged: (value) {
                    Navigator.pop(context, value);
                  },
                ),
                onTap: () => Navigator.pop(context, 10),
              ),
              ListTile(
                title: Text('20 seconds (Default)', style: GoogleFonts.poppins()),
                leading: Radio<int>(
                  value: 20,
                  groupValue: customSeconds,
                  onChanged: (value) {
                    Navigator.pop(context, value);
                  },
                ),
                onTap: () => Navigator.pop(context, 20),
              ),
              ListTile(
                title: Text('30 seconds', style: GoogleFonts.poppins()),
                leading: Radio<int>(
                  value: 30,
                  groupValue: customSeconds,
                  onChanged: (value) {
                    Navigator.pop(context, value);
                  },
                ),
                onTap: () => Navigator.pop(context, 30),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Custom (seconds)',
                    hintText: 'Enter minimum 5 seconds',
                    helperText: 'No maximum limit',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (value) {
                    int? customValue = int.tryParse(value);
                    if (customValue != null && customValue >= 5) {
                      Navigator.pop(context, customValue);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a value of at least 5 seconds'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    ).then((value) {
      if (value != null) {
        setState(() {
          selectedDuration = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timer set to $value seconds'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
  }

  void shareAttendanceLink() {
    String link = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    String message = "Join the attendance session:\n";
    if (lectureName != null) message += "Lecture: $lectureName\n";
    if (year != null && branch != null) message += "Year: $year | Branch: $branch\n";
    message += "Link: $link";
    Share.share(message, subject: "QuickAttendance Session");
  }

  void activateBluetooth() async {
    try {
      // Check if Bluetooth permission is granted
      PermissionStatus bluetoothStatus = await Permission.bluetooth.status;
      PermissionStatus bluetoothScanStatus = await Permission.bluetoothScan.status;
      PermissionStatus bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.status;
      PermissionStatus bluetoothConnectStatus = await Permission.bluetoothConnect.status;

      // Request permissions if not granted
      if (!bluetoothStatus.isGranted || 
          !bluetoothScanStatus.isGranted || 
          !bluetoothAdvertiseStatus.isGranted ||
          !bluetoothConnectStatus.isGranted) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ].request();

        // Check if all permissions granted
        if (statuses.values.any((status) => !status.isGranted)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Bluetooth permissions required. Please enable in settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      // Check if Bluetooth is actually ON
      bool isBluetoothOn = false;
      try {
        if (await FlutterBluePlus.isSupported) {
          var adapterState = await FlutterBluePlus.adapterState.first;
          isBluetoothOn = adapterState == BluetoothAdapterState.on;
        }
      } catch (e) {
        print('⚠️ Could not check Bluetooth adapter state: $e');
        // Fallback: Assume ON if we got permissions
        isBluetoothOn = true;
      }

      if (!isBluetoothOn) {
        // Show dialog asking user to turn on Bluetooth
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                '🔵 Bluetooth is OFF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'Please turn ON Bluetooth in your device settings to continue.',
                style: GoogleFonts.poppins(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Try to open Bluetooth settings
                    await openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: Text(
                    'Open Settings',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
        return;
      }

      // All good - Bluetooth is ON and permissions granted
      // Set the dynamic session-specific device name
      bool nameSet = await BluetoothNameService.setBluetoothName(dynamicDeviceName!);
      
      if (!nameSet) {
        print('⚠️ Warning: Could not set Bluetooth name, but continuing anyway');
      } else {
        print('✅ Bluetooth name set to: $dynamicDeviceName');
      }
      
      setState(() {
        bluetoothActive = true;
      });

      await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
        'bluetooth_active': true,
        'bluetooth_activated_at': DateTime.now().toIso8601String(),
        'bluetooth_device_name': dynamicDeviceName, // NEW: Store dynamic device name
        'connected_devices': [], // NEW: Initialize connected devices list
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Bluetooth Active! Students can now join.\nDevice name: "$dynamicDeviceName"'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Error activating Bluetooth: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void deactivateBluetooth() async {
    setState(() {
      bluetoothActive = false;
    });

    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'bluetooth_active': false,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bluetooth deactivated'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void endAttendance() async {
    // Cancel any active timer
    _timer?.cancel();
    
    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'is_ended': true,
      'ended_at': DateTime.now().toIso8601String(),
      'otp_active': false,
      'bluetooth_active': false,
      'session_status': 'ended', // NEW: Session officially ended
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Attendance session has been ended successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // NEW: Manual add attendance
  void _showAddAttendanceDialog() {
    final TextEditingController rollController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: ThemeHelper.getPrimaryColor(context)),
            SizedBox(width: 12),
            Text('Add Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a student who couldn\'t submit attendance',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            SizedBox(height: 16),
            TextField(
              controller: rollController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Roll Number / Name',
                hintText: 'Enter roll number or name',
                prefixIcon: Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              String value = rollController.text.trim();
              if (value.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a value'), backgroundColor: Colors.red),
                );
                return;
              }
              
              if (markedStudents.contains(value)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('This entry already exists!'), backgroundColor: Colors.orange),
                );
                return;
              }
              
              // Add to Firebase
              DatabaseReference studentsRef = _attendanceRef
                  .child("attendance_sessions/${widget.sessionId}/students");
              String studentId = studentsRef.push().key!;
              await studentsRef.child(studentId).set({
                'entry': value,
                'timestamp': DateTime.now().toIso8601String(),
                'manually_added': true,
                'added_by': 'teacher',
              });
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Added: $value'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // NEW: Remove attendance
  void _showRemoveAttendanceDialog(String entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Remove Attendance', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$entry" from attendance?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Find and remove from Firebase
              DatabaseReference studentsRef = _attendanceRef
                  .child("attendance_sessions/${widget.sessionId}/students");
              final snapshot = await studentsRef.once();
              
              if (snapshot.snapshot.value != null) {
                Map<dynamic, dynamic> students = snapshot.snapshot.value as Map;
                String? keyToRemove;
                
                students.forEach((key, value) {
                  if (value['entry'].toString() == entry) {
                    keyToRemove = key;
                  }
                });
                
                if (keyToRemove != null) {
                  await studentsRef.child(keyToRemove!).remove();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Removed: $entry'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }

  // NEW: Export as PDF
  void _exportAsPDF() async {
    if (lectureName == null) return;

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Classroom Attendance Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Subject: $lectureName', style: pw.TextStyle(fontSize: 16)),
                pw.Text('Year: $year | Branch: $branch', style: pw.TextStyle(fontSize: 14)),
                pw.Text('Session ID: ${widget.sessionId}', style: pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total Students Present: ${markedStudents.length}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Attendance List:',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                // Student list
                ...markedStudents.asMap().entries.map((entry) {
                  int index = entry.key + 1;
                  String student = entry.value;
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 5),
                    child: pw.Text(
                      '$index. $student',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated: ${DateTime.now().toString().substring(0, 19)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Session Link: https://attendo-312ea.web.app/#/session/${widget.sessionId}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.blue),
                ),
              ],
            );
          },
        ),
      );

      // Show dialog with options
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text(
                  'Export PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Choose how you want to export the attendance report',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Preview PDF
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async => pdf.save(),
                  );
                },
                icon: Icon(Icons.visibility_rounded, size: 18),
                label: Text('Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  // Save and share PDF
                  await _saveAndSharePDF(pdf);
                },
                icon: Icon(Icons.share_rounded, size: 18),
                label: Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Save PDF and share it
  Future<void> _saveAndSharePDF(pw.Document pdf) async {
    try {
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = 'Attendance_${lectureName}_$timestamp.pdf';
      final String filePath = '${tempDir.path}/$fileName';

      // Save PDF to file
      final File file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Attendance Report for $lectureName\nTotal Students: ${markedStudents.length}',
        subject: 'Attendance Report - $lectureName',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📤 PDF ready to share!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sharing PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String sessionLink = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          isEnded ? 'Session Ended' : 'Session Active',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          // PDF Export button
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportAsPDF,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session Ended Banner
              if (isEnded) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade600, Colors.orange.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_rounded, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Session Ended',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✅ You can now:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Add students who couldn\'t mark attendance',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Remove incorrect entries',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Export attendance as PDF',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.95),
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
                const SizedBox(height: 20),
              ],

              //               // Session Info Card
              _buildSessionInfoCard(context),
              const SizedBox(height: 20),

              // Attendance Mode Card
              if (!isEnded) ...[
                _buildAttendanceModeCard(context),
                const SizedBox(height: 20),
              ],

              // Bluetooth Activation Card (only if enabled)
              if (!isEnded && bluetoothEnabled) ...[
                _buildBluetoothCard(context),
                const SizedBox(height: 20),
              ],

              // OTP Card
              if (!isEnded) ...[
                _buildOTPCard(context),
                const SizedBox(height: 20),
              ],

              // Live Count Card
              _buildLiveCountCard(context),
              const SizedBox(height: 20),

              // QR Code Section
              if (!isEnded) ...[ 
                _buildQRCodeCard(context, sessionLink),
                const SizedBox(height: 20),
              ],

              // Share Link Section
              if (!isEnded) ...[
                _buildShareLinkCard(context, sessionLink),
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Share Link',
                        icon: Icons.share_rounded,
                        color: ThemeHelper.getPrimaryColor(context),
                        onPressed: shareAttendanceLink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'End Session',
                        icon: Icons.stop_circle_rounded,
                        color: ThemeHelper.getWarningColor(context),
                        onPressed: endAttendance,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Add Student by Roll No button (only when session ended)
              if (isEnded) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showAddAttendanceDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add Student by Roll No',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Manually add students who couldn\'t mark attendance',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Live Attendance Section
              _buildLiveAttendanceSection(context),

              // Cheating Flags Section
              if (cheatingFlags.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildCheatingFlagsSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBluetoothCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bluetoothActive 
            ? Colors.blue.withValues(alpha: 0.1) 
            : ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bluetoothActive 
              ? Colors.blue 
              : Colors.orange.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getShadowColor(context),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        bluetoothActive 
                            ? Icons.bluetooth_connected_rounded 
                            : Icons.bluetooth_disabled_rounded,
                        color: bluetoothActive ? Colors.blue : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bluetooth Status',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: ThemeHelper.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bluetoothActive ? '✅ Active' : '⚠️ Not Active',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: bluetoothActive ? Colors.blue : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!bluetoothActive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Device Name Info',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your device will be renamed to:',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${dynamicDeviceName ?? "Attendo: Teachers Device"}"',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students should look for this name when connecting.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure Bluetooth is ON and device is discoverable',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: bluetoothActive ? deactivateBluetooth : activateBluetooth,
              icon: Icon(
                bluetoothActive 
                    ? Icons.bluetooth_disabled_rounded 
                    : Icons.bluetooth_rounded,
                size: 24,
              ),
              label: Text(
                bluetoothActive ? 'Deactivate Bluetooth' : 'Activate Bluetooth',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: bluetoothActive 
                    ? Colors.grey 
                    : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (bluetoothActive) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth_searching_rounded,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Device Name:',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${dynamicDeviceName ?? "Attendo: Teachers Device"}"',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✓ Students can now detect your device and join',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lectureName ?? 'Loading...',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (year != null && branch != null)
                      Text(
                        '$year • $branch',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOTPCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: otpActive ? Colors.green.withValues(alpha: 0.1) : ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: otpActive 
              ? Colors.green 
              : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getShadowColor(context),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OTP Code',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    otp ?? '----',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: otpActive 
                          ? Colors.green 
                          : ThemeHelper.getPrimaryColor(context),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
              if (otpActive)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$timerSeconds',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: otpActive ? null : activateOTP,
                  icon: Icon(
                    otpActive ? Icons.timer_rounded : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  label: Text(
                    otpActive ? 'OTP Active (${timerSeconds}s)' : 'Activate OTP (${selectedDuration}s)',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: otpActive 
                        ? Colors.grey 
                        : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              if (!otpActive) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _showTimerSelectionDialog,
                    icon: Icon(
                      Icons.settings_rounded,
                      color: ThemeHelper.getPrimaryColor(context),
                    ),
                    tooltip: 'Change timer duration',
                  ),
                ),
              ],
            ],
          ),
          if (otpActive) ...[
            const SizedBox(height: 12),
            Text(
              '⚠️ Tell students the OTP verbally or write on board',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          // NEW: Show time expired status
          if (sessionStatus == 'time_expired' && !otpActive && !isEnded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_off_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⏰ Time Expired',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Students can no longer enter OTP. You can start a new OTP or end the session.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveCountCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getShadowColor(context),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.people_rounded,
              color: ThemeHelper.getSuccessColor(context),
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Students Present',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.getTextSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${markedStudents.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: ThemeHelper.getSuccessColor(context),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: ThemeHelper.getSuccessColor(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.getSuccessColor(context),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildQRCodeCard(BuildContext context, String link) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                color: ThemeHelper.getPrimaryColor(context),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Scan QR Code to Join',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Students can scan this code',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: ThemeHelper.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareLinkCard(BuildContext context, String link) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getShadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: ThemeHelper.getPrimaryColor(context),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Session Link',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Link copied to clipboard',
                          style: GoogleFonts.poppins(),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: ThemeHelper.getSuccessColor(context),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getPrimaryColor(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAttendanceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Attendance',
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
                      'No students yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students will appear here as they mark attendance',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
                  : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: markedStudents.map((rollNo) {
                    bool isFlagged = cheatingFlags.containsKey(rollNo);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isFlagged 
                            ? Colors.red.withValues(alpha: 0.1)
                            : ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFlagged
                              ? Colors.red.withValues(alpha: 0.5)
                              : ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFlagged ? Icons.warning_rounded : Icons.check_circle_rounded,
                            size: 18,
                            color: isFlagged ? Colors.red : ThemeHelper.getSuccessColor(context),
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
                          // Delete button (only when session ended)
                          if (isEnded) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showRemoveAttendanceDialog(rollNo),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCheatingFlagsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flag_rounded,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Suspicious Activity',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cheatingFlags.entries.map((entry) {
          String rollNo = entry.key;
          Map<String, dynamic> flags = Map<String, dynamic>.from(entry.value);
          String severity = flags['severity'] ?? 'MEDIUM';
          
          Color severityColor = severity == 'HIGH' 
              ? Colors.red 
              : severity == 'MEDIUM' 
                  ? Colors.orange 
                  : Colors.yellow.shade700;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: severityColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Roll $rollNo',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        severity,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Tab switched/minimized: ${flags['tabSwitched'] ? 'Yes' : 'No'}',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                Text(
                  '• Focus lost count: ${flags['focusLostCount']}',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                Text(
                  '• Total focus loss time: ${flags['totalFocusLossTime']}s',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAttendanceModeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bluetoothEnabled 
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bluetoothEnabled 
              ? Colors.blue.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: bluetoothEnabled 
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bluetoothEnabled 
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              bluetoothEnabled 
                  ? Icons.security_rounded 
                  : Icons.wifi_rounded,
              color: bluetoothEnabled 
                  ? Colors.blue 
                  : Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bluetoothEnabled 
                      ? 'High Security Mode' 
                      : 'Remote Attendance Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: bluetoothEnabled 
                        ? Colors.blue.shade700 
                        : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bluetoothEnabled 
                      ? 'Students must be physically present + OTP verification' 
                      : 'Students can join from anywhere with OTP only',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: bluetoothEnabled 
                        ? Colors.blue.shade600 
                        : Colors.orange.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bluetoothEnabled 
                  ? Colors.blue 
                  : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bluetoothEnabled 
                  ? 'BT + OTP' 
                  : 'OTP ONLY',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
