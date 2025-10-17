import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/models/quiz_models.dart';

class QuizReviewScreen extends StatefulWidget {
  final String quizId;
  final String participantId;

  const QuizReviewScreen({
    Key? key,
    required this.quizId,
    required this.participantId,
  }) : super(key: key);

  @override
  _QuizReviewScreenState createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  QuizSession? quizSession;
  List<int> userAnswers = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuizAndAnswers();
  }

  Future<void> _loadQuizAndAnswers() async {
    try {
      // Load quiz session
      final quizSnapshot = await _dbRef.child('quiz_sessions/${widget.quizId}').get();
      if (!quizSnapshot.exists) return;

      final quizData = Map<String, dynamic>.from(quizSnapshot.value as Map);
      final quiz = QuizSession.fromJson(widget.quizId, quizData);

      // Load participant's answers
      final participantSnapshot = await _dbRef
          .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}')
          .get();
      
      List<int> answers = [];
      if (participantSnapshot.exists) {
        final participantData = Map<String, dynamic>.from(participantSnapshot.value as Map);
        if (participantData['answers'] != null) {
          answers = List<int>.from(participantData['answers']);
        }
      }

      setState(() {
        quizSession = quiz;
        userAnswers = answers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading quiz review: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xff8b5cf6)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Review Answers',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xff8b5cf6), const Color(0xff8b5cf6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz_rounded, color: Colors.white, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quizSession?.quizName ?? 'Quiz Review',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${quizSession?.questions.length ?? 0} Questions',
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
              ),
              const SizedBox(height: 24),

              // Questions List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quizSession?.questions.length ?? 0,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final question = quizSession!.questions[index];
                  final userAnswerIndex = userAnswers.length > index ? userAnswers[index] : -1;
                  final isCorrect = userAnswerIndex == question.correctAnswerIndex;
                  final isUnanswered = userAnswerIndex == -1;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUnanswered 
                            ? Colors.grey 
                            : isCorrect 
                                ? Colors.green 
                                : Colors.red,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isUnanswered 
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : isCorrect 
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isUnanswered 
                                        ? Icons.remove_circle_outline 
                                        : isCorrect 
                                            ? Icons.check_circle_rounded 
                                            : Icons.cancel_rounded,
                                    color: isUnanswered 
                                        ? Colors.grey 
                                        : isCorrect 
                                            ? Colors.green 
                                            : Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isUnanswered 
                                        ? 'Not Answered' 
                                        : isCorrect 
                                            ? 'Correct' 
                                            : 'Incorrect',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isUnanswered 
                                          ? Colors.grey 
                                          : isCorrect 
                                              ? Colors.green 
                                              : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Question Text
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q${index + 1}.',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff8b5cf6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                question.question,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Options
                        ...List.generate(question.options.length, (optionIndex) {
                          final isUserAnswer = optionIndex == userAnswerIndex;
                          final isCorrectAnswer = optionIndex == question.correctAnswerIndex;
                          
                          Color? backgroundColor;
                          Color? borderColor;
                          Color? textColor;
                          IconData? icon;

                          if (isCorrectAnswer) {
                            backgroundColor = Colors.green.withValues(alpha: 0.1);
                            borderColor = Colors.green;
                            textColor = Colors.green;
                            icon = Icons.check_circle_rounded;
                          } else if (isUserAnswer && !isCorrect) {
                            backgroundColor = Colors.red.withValues(alpha: 0.1);
                            borderColor = Colors.red;
                            textColor = Colors.red;
                            icon = Icons.cancel_rounded;
                          } else {
                            backgroundColor = ThemeHelper.getBackgroundColor(context);
                            borderColor = ThemeHelper.getBorderColor(context);
                            textColor = ThemeHelper.getTextPrimary(context);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: (isCorrectAnswer || (isUserAnswer && !isCorrect))
                                        ? (isCorrectAnswer ? Colors.green : Colors.red)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: icon != null
                                        ? Icon(icon, color: Colors.white, size: 18)
                                        : Text(
                                            String.fromCharCode(65 + optionIndex),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    question.options[optionIndex],
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: (isCorrectAnswer || isUserAnswer) 
                                          ? FontWeight.w600 
                                          : FontWeight.normal,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (isCorrectAnswer)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Correct',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (isUserAnswer && !isCorrect)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Your Answer',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
