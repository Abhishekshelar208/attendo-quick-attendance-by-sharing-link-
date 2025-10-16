import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/models/quiz_models.dart';
import 'package:attendo/pages/QuizResultsScreen.dart';

class StudentQuizScreen extends StatefulWidget {
  final String quizId;
  final String participantId;

  const StudentQuizScreen({
    Key? key,
    required this.quizId,
    required this.participantId,
  }) : super(key: key);

  @override
  _StudentQuizScreenState createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  QuizSession? quizSession;
  int currentQuestionIndex = 0;
  List<int> selectedAnswers = [];
  List<int> questionOrder = []; // Shuffled order of questions
  bool isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuizAndAnswers();
    _listenForQuizEnd();
  }

  Future<void> _loadQuizAndAnswers() async {
    try {
      final snapshot = await _dbRef.child('quiz_sessions/${widget.quizId}').get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final quiz = QuizSession.fromJson(widget.quizId, data);

        // Load existing answers if any
        final participantSnapshot = await _dbRef
            .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}')
            .get();
        
        List<int> answers = List.filled(quiz.questions.length, -1);
        List<int> shuffledOrder = List.generate(quiz.questions.length, (index) => index);
        
        if (participantSnapshot.exists) {
          final participantData = Map<String, dynamic>.from(participantSnapshot.value as Map);
          if (participantData['answers'] != null) {
            answers = List<int>.from(participantData['answers']);
          }
          // Load saved question order if exists
          if (participantData['question_order'] != null) {
            shuffledOrder = List<int>.from(participantData['question_order']);
          } else {
            // First time: shuffle and save
            shuffledOrder.shuffle();
            await _dbRef
                .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}/question_order')
                .set(shuffledOrder);
          }
        } else {
          // First time: shuffle and save
          shuffledOrder.shuffle();
          await _dbRef
              .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}/question_order')
              .set(shuffledOrder);
        }

        setState(() {
          quizSession = quiz;
          selectedAnswers = answers;
          questionOrder = shuffledOrder;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quiz: $e');
      if (mounted) {
        EnhancedSnackBar.show(
          context,
          message: 'Error loading quiz',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _listenForQuizEnd() {
    _dbRef.child('quiz_sessions/${widget.quizId}/status').onValue.listen((event) {
      if (event.snapshot.value == 'ended' && mounted) {
        _handleQuizEnd();
      }
    });
  }

  Future<void> _selectAnswer(int answerIndex) async {
    final actualQuestionIndex = questionOrder[currentQuestionIndex];
    setState(() {
      selectedAnswers[actualQuestionIndex] = answerIndex;
    });

    // Save answer to Firebase immediately
    try {
      await _dbRef
          .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}/answers')
          .set(selectedAnswers);
    } catch (e) {
      print('Error saving answer: $e');
    }
  }

  void _nextQuestion() {
    if (currentQuestionIndex < quizSession!.questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitQuiz() async {
    // Check if all questions are answered
    bool hasUnanswered = selectedAnswers.contains(-1);
    
    if (hasUnanswered) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Incomplete Quiz', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'You have unanswered questions. Do you want to submit anyway?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: Text('Submit', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => isSubmitting = true);

    try {
      // Calculate score
      int score = 0;
      for (int i = 0; i < quizSession!.questions.length; i++) {
        if (selectedAnswers[i] == quizSession!.questions[i].correctAnswerIndex) {
          score++;
        }
      }

      // Update participant data
      await _dbRef
          .child('quiz_sessions/${widget.quizId}/participants/${widget.participantId}')
          .update({
        'answers': selectedAnswers,
        'score': score,
        'completed_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QuizResultsScreen(
              quizId: widget.quizId,
              participantId: widget.participantId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error submitting quiz: $e');
      if (mounted) {
        setState(() => isSubmitting = false);
        EnhancedSnackBar.show(
          context,
          message: 'Error submitting quiz',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _handleQuizEnd() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Quiz Ended', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'The teacher has ended this quiz. Your answers will be submitted automatically.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    final actualQuestionIndex = questionOrder[currentQuestionIndex];
    final currentQuestion = quizSession!.questions[actualQuestionIndex];
    final totalQuestions = quizSession!.questions.length;
    final progress = (currentQuestionIndex + 1) / totalQuestions;

    return WillPopScope(
      onWillPop: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit Quiz?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            content: Text(
              'Are you sure you want to exit? Your answers will be saved.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Exit', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            quizSession!.quizName,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Question Counter
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.purple.withValues(alpha: 0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${currentQuestionIndex + 1} of $totalQuestions',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${selectedAnswers.where((a) => a != -1).length}/$totalQuestions answered',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Question Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: ThemeHelper.getCardColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.purple, width: 2),
                            ),
                            child: Text(
                              currentQuestion.question,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.getTextPrimary(context),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Options
                          Text(
                            'Select your answer:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...currentQuestion.options.asMap().entries.map((entry) {
                            int optionIndex = entry.key;
                            String option = entry.value;
                            bool isSelected = selectedAnswers[actualQuestionIndex] == optionIndex;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _selectAnswer(optionIndex),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.purple.withValues(alpha: 0.1)
                                        : ThemeHelper.getCardColor(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? Colors.purple : ThemeHelper.getBorderColor(context),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? Colors.purple : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? Colors.purple : Colors.grey,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                                            : Center(
                                                child: Text(
                                                  String.fromCharCode(65 + optionIndex), // A, B, C, D
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          option,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: ThemeHelper.getTextPrimary(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Navigation Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (currentQuestionIndex > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _previousQuestion,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text('Previous', style: GoogleFonts.poppins()),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.purple, width: 2),
                              ),
                            ),
                          ),
                        if (currentQuestionIndex > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: selectedAnswers[actualQuestionIndex] != -1
                                ? _nextQuestion
                                : null,
                            icon: Icon(
                              currentQuestionIndex == totalQuestions - 1
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              currentQuestionIndex == totalQuestions - 1 ? 'Submit Quiz' : 'Next',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Submitting Overlay
            if (isSubmitting)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.purple),
                          const SizedBox(height: 16),
                          Text(
                            'Submitting quiz...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
