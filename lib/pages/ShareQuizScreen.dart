import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'TeacherQuizDashboard.dart';

class ShareQuizScreen extends StatefulWidget {
  final String quizId;

  const ShareQuizScreen({Key? key, required this.quizId}) : super(key: key);

  @override
  _ShareQuizScreenState createState() => _ShareQuizScreenState();
}

class _ShareQuizScreenState extends State<ShareQuizScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? quizData;
  bool isLoading = true;
  String quizUrl = '';

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    try {
      final snapshot = await _dbRef.child('quiz_sessions/${widget.quizId}').get();
      if (snapshot.exists) {
        setState(() {
          quizData = Map<String, dynamic>.from(snapshot.value as Map);
          // TODO: Replace with your actual deployed URL
          quizUrl = 'https://attendo-312ea.web.app/#/quiz/${widget.quizId}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quiz: $e');
      setState(() => isLoading = false);
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: quizUrl));
    EnhancedSnackBar.show(
      context,
      message: 'Link copied to clipboard! 📋',
      type: SnackBarType.success,
    );
  }

  void _shareQuiz() {
    final text = '''
🎯 ${quizData?['quiz_name'] ?? 'Quiz'}

${quizData?['description'] ?? ''}

📅 Date: ${quizData?['date']}
⏰ Time: ${quizData?['time']}

Join the quiz:
$quizUrl
''';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Share Quiz',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // Navigate back to home screen
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xff8b5cf6), const Color(0xff8b5cf6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quiz Created Successfully!',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share this quiz with your students',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Quiz Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xff8b5cf6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.quiz_rounded, color: const Color(0xff8b5cf6)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quizData?['quiz_name'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                              Text(
                                '${(quizData?['questions'] as List?)?.length ?? 0} Questions',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.calendar_today_rounded, 'Date', quizData?['date'] ?? ''),
                    _buildInfoRow(Icons.access_time_rounded, 'Time', quizData?['time'] ?? ''),
                    _buildInfoRow(Icons.school_rounded, 'Class', 
                        '${quizData?['year']} ${quizData?['branch']} ${quizData?['division']}'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // QR Code
              Text(
                'Scan QR Code',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
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
                  data: quizUrl,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Share Buttons
              Text(
                'Or Share Link',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              
              // Link Display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        quizUrl,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: ThemeHelper.getPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: _copyLink,
                      tooltip: 'Copy Link',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Copy Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(
                    'Copy Link',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getPrimaryColor(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Share Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _shareQuiz,
                  icon: const Icon(Icons.share_rounded),
                  label: Text(
                    'Share Quiz',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ThemeHelper.getPrimaryColor(context), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Dashboard Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TeacherQuizDashboard(quizId: widget.quizId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard_rounded),
                  label: Text(
                    'View Live Dashboard',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff8b5cf6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ThemeHelper.getTextSecondary(context)),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.getTextSecondary(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
