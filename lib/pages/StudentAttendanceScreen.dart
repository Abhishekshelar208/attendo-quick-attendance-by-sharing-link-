import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'StudentViewAttendanceScreen.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String sessionId;

  StudentAttendanceScreen({required this.sessionId});

  @override
  _StudentAttendanceScreenState createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final TextEditingController _inputController = TextEditingController();
  String? lectureName;
  String? inputType; // Will be either "Roll Number" or "Name"
  String? year;
  String? branch;
  bool isEnded = false;
  List<String> markedStudents = [];
  String? alreadyMarkedEntry; // Store if device already marked attendance
  bool isCheckingDevice = true; // Loading state for device check

  @override
  void initState() {
    super.initState();
    _checkDeviceAttendance();
    _fetchSessionDetails();
  }

  // Generate unique device fingerprint using browser/device characteristics
  Future<String> _getDeviceId() async {
    // Use advanced browser fingerprinting
    return await DeviceFingerprintService.getFingerprint();
  }
  
  // Check if this device already marked attendance for this session
  Future<void> _checkDeviceAttendance() async {
    try {
      final deviceId = await _getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final key = 'attendance_${widget.sessionId}';
      
      // Check localStorage first
      final storedEntry = prefs.getString(key);
      
      if (storedEntry != null) {
        // Device already marked attendance
        setState(() {
          alreadyMarkedEntry = storedEntry;
          isCheckingDevice = false;
        });
        
        // Navigate to view screen after short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentViewAttendanceScreen(
                  sessionId: widget.sessionId,
                  markedEntry: storedEntry,
                ),
              ),
            );
          }
        });
        return;
      }
      
      // Check Firebase for device ID
      DatabaseReference studentsRef = FirebaseDatabase.instance
          .ref()
          .child("attendance_sessions/${widget.sessionId}/students");
      
      DatabaseEvent event = await studentsRef.once();
      
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        
        // Check if this device ID already exists
        for (var student in studentsMap.values) {
          if (student['device_id'] == deviceId) {
            final entry = student['entry'].toString();
            
            // Store in localStorage for faster future checks
            await prefs.setString(key, entry);
            
            setState(() {
              alreadyMarkedEntry = entry;
              isCheckingDevice = false;
            });
            
            // Navigate to view screen
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentViewAttendanceScreen(
                      sessionId: widget.sessionId,
                      markedEntry: entry,
                    ),
                  ),
                );
              }
            });
            return;
          }
        }
      }
      
      // Device hasn't marked attendance yet
      setState(() {
        isCheckingDevice = false;
      });
      
    } catch (e) {
      print('Error checking device attendance: $e');
      setState(() {
        isCheckingDevice = false;
      });
    }
  }

  void _fetchSessionDetails() async {
    DatabaseReference sessionRef =
    FirebaseDatabase.instance.ref().child("attendance_sessions/${widget.sessionId}");

    sessionRef.once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['subject'];
          inputType = data['type']; // "Roll Number" or "Name"
          year = data['year'];
          branch = data['branch'];
          isEnded = data['is_ended'] ?? false;
          
          // If ended, fetch the attendance list
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

  void submitAttendance() async {
    if (_inputController.text.isEmpty) return;

    String enteredValue = _inputController.text.trim();
    final deviceId = await _getDeviceId();

    // Check if roll number already exists
    DatabaseReference dbRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}/students");
    
    DatabaseEvent event = await dbRef.once();
    
    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
      List<String> existingEntries = studentsMap.values.map((e) => e['entry'].toString()).toList();
      
      // Check for duplicate roll number/name
      if (existingEntries.contains(enteredValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("This $inputType is already marked!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Add new attendance entry with device ID
    String studentId = dbRef.push().key!;
    await dbRef.child(studentId).set({
      'entry': enteredValue,
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Store in localStorage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendance_${widget.sessionId}', enteredValue);

    // Navigate to StudentViewAttendanceScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StudentViewAttendanceScreen(
          sessionId: widget.sessionId,
          markedEntry: enteredValue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Close the app/tab instead of going back
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            "Mark Attendance.",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
        ),
        body: isCheckingDevice || inputType == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: ThemeHelper.getPrimaryColor(context),
                    ),
                    const SizedBox(height: 20),
                    if (alreadyMarkedEntry != null)
                      Text(
                        'Already marked as: $alreadyMarkedEntry',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: ThemeHelper.getTextSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              )
            : isEnded
            ? _buildEndedView()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      
                      // Welcome Icon/Animation
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
                      const SizedBox(height: 24),
                      
                      // Session Info Card
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
                                  'Mark Your Presence',
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
                              'Enter your details below to confirm attendance',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 28),
                            
                            // Input Field
                            TextField(
                              controller: _inputController,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: inputType,
                                hintText: 'Enter your $inputType',
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
                              onSubmitted: (_) => submitAttendance(),
                            ),
                            const SizedBox(height: 28),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: submitAttendance,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeHelper.getSuccessColor(context),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 28),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Submit Attendance',
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
                      const SizedBox(height: 20),
                      
                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please ensure your $inputType is correct before submitting',
                                style: GoogleFonts.poppins(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEndedView() {
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
                  : Wrap(
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
            ),
            const SizedBox(height: 40),
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
