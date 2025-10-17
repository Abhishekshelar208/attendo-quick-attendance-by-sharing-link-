import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/models/quiz_models.dart';
import 'package:attendo/pages/StudentQuizScreen.dart';
import 'package:lottie/lottie.dart';

class StudentQuizEntryScreen extends StatefulWidget {
  final String quizId;

  const StudentQuizEntryScreen({Key? key, required this.quizId}) : super(key: key);

  @override
  _StudentQuizEntryScreenState createState() => _StudentQuizEntryScreenState();
}

class _StudentQuizEntryScreenState extends State<StudentQuizEntryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final _formKey = GlobalKey<FormState>();
  
  QuizSession? quizSession;
  bool isLoading = true;
  bool isJoining = false;
  bool isQuizEnded = false;
  Map<String, TextEditingController> fieldControllers = {};

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    try {
      final snapshot = await _dbRef.child('quiz_sessions/${widget.quizId}').get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final quiz = QuizSession.fromJson(widget.quizId, data);
        
        if (quiz.status == 'ended') {
          setState(() {
            quizSession = quiz;
            isQuizEnded = true;
            isLoading = false;
          });
          return;
        }

        // Initialize controllers for custom fields
        for (var field in quiz.customFields) {
          fieldControllers[field.name] = TextEditingController();
        }

        setState(() {
          quizSession = quiz;
          isLoading = false;
        });
      } else {
        if (mounted) {
          EnhancedSnackBar.show(
            context,
            message: 'Quiz not found',
            type: SnackBarType.error,
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error loading quiz: $e');
      if (mounted) {
        EnhancedSnackBar.show(
          context,
          message: 'Error loading quiz: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _joinQuiz() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => isJoining = true);

    try {
      // Collect custom field values
      Map<String, dynamic> customFieldValues = {};
      fieldControllers.forEach((key, controller) {
        customFieldValues[key] = controller.text.trim();
      });

      // Generate participant ID
      final participantRef = _dbRef.child('quiz_sessions/${widget.quizId}/participants').push();
      final participantId = participantRef.key!;

      // Create participant data
      final participant = QuizParticipant(
        participantId: participantId,
        customFieldValues: customFieldValues,
        answers: List.filled(quizSession!.questions.length, -1), // -1 means not answered
        score: 0,
        rank: 0,
      );

      // Save to Firebase
      await participantRef.set(participant.toJson());

      if (mounted) {
        setState(() => isJoining = false);
        
        EnhancedSnackBar.show(
          context,
          message: 'Joined successfully! Good luck! 🎉',
          type: SnackBarType.success,
        );

        // Navigate to quiz screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StudentQuizScreen(
              quizId: widget.quizId,
              participantId: participantId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error joining quiz: $e');
      if (mounted) {
        setState(() => isJoining = false);
        EnhancedSnackBar.show(
          context,
          message: 'Error joining quiz: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    fieldControllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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

    if (isQuizEnded) {
      return _buildQuizEndedView();
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Join Quiz',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quiz Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xff8b5cf6), const Color(0xff8b5cf6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
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
                              Icons.quiz_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quizSession!.quizName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${quizSession!.questions.length} Questions',
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
                      if (quizSession!.description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          quizSession!.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildInfoChip(Icons.calendar_today_rounded, quizSession!.date),
                          const SizedBox(width: 8),
                          _buildInfoChip(Icons.access_time_rounded, quizSession!.time),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Instructions
                Text(
                  'Enter Your Details',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fill in all the required information below to join the quiz',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic Form Fields
                ...quizSession!.customFields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${field.name}${field.required ? ' *' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: fieldControllers[field.name],
                          decoration: InputDecoration(
                            hintText: 'Enter your ${field.name.toLowerCase()}',
                            prefixIcon: Icon(_getIconForField(field.name)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: field.required
                              ? (value) => value?.isEmpty ?? true
                                  ? '${field.name} is required'
                                  : null
                              : null,
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Join Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isJoining ? null : _joinQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff8b5cf6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isJoining
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            'Join Quiz',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForField(String fieldName) {
    final name = fieldName.toLowerCase();
    if (name.contains('name')) return Icons.person_rounded;
    if (name.contains('id') || name.contains('roll')) return Icons.badge_rounded;
    if (name.contains('email')) return Icons.email_rounded;
    if (name.contains('phone')) return Icons.phone_rounded;
    return Icons.input_rounded;
  }

  Widget _buildQuizEndedView() {
    final participants = quizSession?.participants.values.toList() ?? [];
    final sortedParticipants = participants.toList()
      ..sort((a, b) {
        final scoreA = a.score ?? 0;
        final scoreB = b.score ?? 0;
        return scoreB.compareTo(scoreA);
      });

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Quiz Ended',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
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
                    'Quiz Has Ended',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This quiz has been closed by the teacher',
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiz Details',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow2(Icons.quiz_rounded, 'Quiz', quizSession!.quizName),
                  const SizedBox(height: 16),
                  _buildDetailRow2(Icons.help_outline_rounded, 'Questions', '${quizSession!.questions.length}'),
                  const SizedBox(height: 16),
                  _buildDetailRow2(Icons.people_rounded, 'Participants', '${participants.length}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (quizSession?.showLeaderboard ?? true) ...[
              Text(
                'Final Leaderboard',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                ),
                child: sortedParticipants.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No participants',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedParticipants.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: ThemeHelper.getBorderColor(context)),
                        itemBuilder: (context, index) {
                          final participant = sortedParticipants[index];
                          final name = participant.customFieldValues['Name'] ?? 'Student';
                          final score = participant.score ?? 0;

                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff8b5cf6).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xff8b5cf6),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$score/${quizSession!.questions.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xff8b5cf6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: ThemeHelper.getTextSecondary(context),
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'The teacher has kept the results private.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow2(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: ThemeHelper.getPrimaryColor(context)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
    );
  }
}
