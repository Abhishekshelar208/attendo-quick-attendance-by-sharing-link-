import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';

class StudentViewAttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String? markedEntry; // The entry this device marked

  StudentViewAttendanceScreen({
    required this.sessionId,
    this.markedEntry,
  });

  @override
  _StudentViewAttendanceScreenState createState() => _StudentViewAttendanceScreenState();
}

class _StudentViewAttendanceScreenState extends State<StudentViewAttendanceScreen> {
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref();
  List<String> markedStudents = [];
  String? lectureName;
  String? year;
  String? branch;
  String? date;
  String? time;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
    _listenForAttendanceUpdates();
  }

  // Fetch session details
  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = _attendanceRef.child("attendance_sessions/${widget.sessionId}");
    sessionRef.once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['subject'];
          year = data['year'];
          branch = data['branch'];
          date = data['date'];
          time = data['time'];
        });
      }
    });
  }

  // Listen for live attendance updates
  void _listenForAttendanceUpdates() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/students").onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> updatedStudents = studentsMap.values.map((e) => e['entry'].toString()).toList();

        // Sort in ascending order (numeric if possible, otherwise alphabetic)
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
            "QuickPro.",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              
              // Success Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeHelper.getSuccessColor(context),
                        ThemeHelper.getSuccessColor(context).withValues(alpha: 0.8),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Success Message Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeHelper.getSuccessColor(context),
                      ThemeHelper.getSuccessColor(context).withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Attendance Marked Successfully!',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (widget.markedEntry != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'You marked as: ${widget.markedEntry}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Session Info Card
              if (lectureName != null || (year != null && branch != null) || (date != null && time != null))
                Container(
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
                  child: Column(
                    children: [
                      if (lectureName != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.book_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lectureName!,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (lectureName != null && (year != null || date != null))
                        const SizedBox(height: 12),
                      if (year != null && branch != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$year • $branch',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((year != null && branch != null) && (date != null || time != null))
                        const SizedBox(height: 12),
                      if (date != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              date!,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (date != null && time != null)
                        const SizedBox(height: 12),
                      if (time != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              time!,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Device Lock Warning
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
                      Icons.lock_rounded,
                      color: ThemeHelper.getPrimaryColor(context),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This device is locked for this session. You cannot mark attendance again.',
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
              
              const SizedBox(height: 32),
              
              // Live Attendance Section
              Text(
                'Students Present',
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
                              final isCurrentUser = rollNo == widget.markedEntry;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                                      : ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrentUser
                                        ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3)
                                        : ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCurrentUser
                                          ? Icons.person_rounded
                                          : Icons.check_circle_rounded,
                                      size: 18,
                                      color: isCurrentUser
                                          ? ThemeHelper.getPrimaryColor(context)
                                          : ThemeHelper.getSuccessColor(context),
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
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        '(You)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: ThemeHelper.getPrimaryColor(context),
                                        ),
                                      ),
                                    ],
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
      ),
    );
  }
}
