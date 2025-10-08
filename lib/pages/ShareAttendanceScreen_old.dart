import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ShareAttendanceScreen extends StatefulWidget {
  final String sessionId;

  ShareAttendanceScreen({required this.sessionId});

  @override
  _ShareAttendanceScreenState createState() => _ShareAttendanceScreenState();
}

class _ShareAttendanceScreenState extends State<ShareAttendanceScreen> {
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref();
  List<String> markedStudents = [];
  String? lectureName;
  String? year;
  String? branch;
  bool isEnded = false;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
    _listenForAttendanceUpdates();
  }

  // Fetch session details
  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = _attendanceRef.child("attendance_sessions/${widget.sessionId}");
    sessionRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['subject'];
          year = data['year'];
          branch = data['branch'];
          isEnded = data['is_ended'] ?? false;
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

  void shareAttendanceLink() {
    String link = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    String message = "Join the attendance session:\n";
    if (lectureName != null) message += "Lecture: $lectureName\n";
    if (year != null && branch != null) message += "Year: $year | Branch: $branch\n";
    message += "Link: $link";
    Share.share(message, subject: "QuickAttendance Session");
  }

  void endAttendance() async {
    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'is_ended': true,
      'ended_at': DateTime.now().toIso8601String(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Attendance session has been ended"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void exportAttendanceText() {
    DateTime now = DateTime.now();
    String formattedDate = "${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year}";
    String formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    String report = "📅 Attendance Report\n";
    if (lectureName != null) report += "📚 Subject: $lectureName\n";
    report += "🗓 Date: $formattedDate\n";
    report += "🕐 Time: $formattedTime\n";
    if (year != null) report += "🧑 Year: $year\n";
    if (branch != null) report += "💼 Branch: $branch\n";
    report += "\n✅ Present Roll Numbers:\n";
    report += "[${markedStudents.join(', ')}]\n";
    report += "\nTotal Present: ${markedStudents.length}\n";
    report += "\n🔗 Session Link (Proof):\n";
    report += "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    
    Share.share(report, subject: "Attendance Report - $lectureName");
  }

  void exportAttendancePDF() async {
    if (lectureName == null) return;

    final pdf = pw.Document();
    DateTime now = DateTime.now();
    String formattedDate = "${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year}";
    String formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
              pw.Text('Date: $formattedDate', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Time: $formattedTime', style: pw.TextStyle(fontSize: 14)),
              if (year != null) pw.Text('Year: $year', style: pw.TextStyle(fontSize: 14)),
              if (branch != null) pw.Text('Branch: $branch', style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Total Present: ${markedStudents.length}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Student Roll Numbers:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...markedStudents.asMap().entries.map((entry) {
                int index = entry.key + 1;
                String rollNo = entry.value;
                return pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 5),
                  child: pw.Text('$index. $rollNo', style: pw.TextStyle(fontSize: 14)),
                );
              }).toList(),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Session Link: https://attendo-312ea.web.app/#/session/${widget.sessionId}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.Text(
                'Generated on: $formattedDate at $formattedTime',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Attendance_${lectureName}_$formattedDate.pdf',
    );
  }
  
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    String sessionLink = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Session Active',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session Info Card
              _buildSessionInfoCard(context),
              const SizedBox(height: 20),

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
              ] else ...[
                // Session Ended Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: ThemeHelper.getWarningColor(context),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session Ended',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Students can no longer join',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Export PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        color: ThemeHelper.getSuccessColor(context),
                        onPressed: exportAttendancePDF,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        context,
                        label: 'Export Text',
                        icon: Icons.text_snippet_rounded,
                        color: ThemeHelper.getPrimaryColor(context),
                        onPressed: exportAttendanceText,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Live Attendance Section
              _buildLiveAttendanceSection(context),
            ],
          ),
        ),
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
      ],
    );
  }
}
