import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/models/quiz_models.dart';
import 'package:attendo/pages/ShareQuizScreen.dart';

class QuizQuestionsScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const QuizQuestionsScreen({Key? key, required this.quizData}) : super(key: key);

  @override
  _QuizQuestionsScreenState createState() => _QuizQuestionsScreenState();
}

class _QuizQuestionsScreenState extends State<QuizQuestionsScreen> {
  List<QuizQuestion> questions = [];
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Start with one empty question
    _addQuestion();
  }

  void _addQuestion() {
    setState(() {
      questions.add(QuizQuestion(
        question: '',
        options: ['', ''],
        correctAnswerIndex: 0,
      ));
    });
  }

  void _removeQuestion(int index) {
    if (questions.length > 1) {
      setState(() {
        questions.removeAt(index);
      });
    } else {
      EnhancedSnackBar.show(
        context,
        message: 'At least one question is required',
        type: SnackBarType.warning,
      );
    }
  }

  void _addOption(int questionIndex) {
    if (questions[questionIndex].options.length < 6) {
      setState(() {
        questions[questionIndex].options.add('');
      });
    } else {
      EnhancedSnackBar.show(
        context,
        message: 'Maximum 6 options allowed',
        type: SnackBarType.warning,
      );
    }
  }

  void _removeOption(int questionIndex, int optionIndex) {
    if (questions[questionIndex].options.length > 2) {
      setState(() {
        questions[questionIndex].options.removeAt(optionIndex);
        // Adjust correct answer if needed
        if (questions[questionIndex].correctAnswerIndex >= questions[questionIndex].options.length) {
          questions[questionIndex].correctAnswerIndex = questions[questionIndex].options.length - 1;
        }
      });
    } else {
      EnhancedSnackBar.show(
        context,
        message: 'At least 2 options are required',
        type: SnackBarType.warning,
      );
    }
  }

  bool _validateQuestions() {
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      
      if (q.question.trim().isEmpty) {
        EnhancedSnackBar.show(
          context,
          message: 'Question ${i + 1}: Question text is required',
          type: SnackBarType.error,
        );
        return false;
      }

      for (int j = 0; j < q.options.length; j++) {
        if (q.options[j].trim().isEmpty) {
          EnhancedSnackBar.show(
            context,
            message: 'Question ${i + 1}: Option ${j + 1} is required',
            type: SnackBarType.error,
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _generateQuiz() async {
    if (!_validateQuestions()) {
      return;
    }

    setState(() => isGenerating = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final dbRef = FirebaseDatabase.instance.ref().child('quiz_sessions');
      final sessionId = dbRef.push().key!;

      final quizSession = QuizSession(
        quizId: sessionId,
        quizName: widget.quizData['quiz_name'],
        description: widget.quizData['description'],
        year: widget.quizData['year'],
        branch: widget.quizData['branch'],
        division: widget.quizData['division'],
        date: widget.quizData['date'],
        time: widget.quizData['time'],
        quizType: widget.quizData['quiz_type'],
        status: 'active',
        createdAt: DateTime.now().toIso8601String(),
        creatorUid: currentUser?.uid ?? '',
        creatorName: currentUser?.displayName ?? 'Unknown',
        creatorEmail: currentUser?.email ?? '',
        generationMethod: 'manual',
        customFields: List<CustomField>.from(widget.quizData['custom_fields']),
        questions: questions,
        participants: {},
      );

      await dbRef.child(sessionId).set(quizSession.toJson());

      if (mounted) {
        setState(() => isGenerating = false);
        
        EnhancedSnackBar.show(
          context,
          message: 'Quiz created successfully! 🎉',
          type: SnackBarType.success,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ShareQuizScreen(quizId: sessionId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isGenerating = false);
        EnhancedSnackBar.show(
          context,
          message: 'Error creating quiz: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Add Questions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.quiz_rounded, color: ThemeHelper.getPrimaryColor(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.quizData['quiz_name'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ThemeHelper.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              '${questions.length} ${questions.length == 1 ? 'Question' : 'Questions'}',
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
                ),

                // Questions List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: questions.length,
                    itemBuilder: (context, index) => _buildQuestionCard(index),
                  ),
                ),

                // Bottom Actions
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Add Question', style: GoogleFonts.poppins()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: isGenerating ? null : _generateQuiz,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: ThemeHelper.getPrimaryColor(context),
                        ),
                        child: Text(
                          'Generate Quiz',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (isGenerating)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: ThemeHelper.getPrimaryColor(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Creating quiz...',
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
    );
  }

  Widget _buildQuestionCard(int questionIndex) {
    final question = questions[questionIndex];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getPrimaryColor(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${questionIndex + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  color: Colors.red,
                  onPressed: () => _removeQuestion(questionIndex),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            TextField(
              decoration: InputDecoration(
                labelText: 'Question',
                hintText: 'Enter your question here',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.help_outline_rounded),
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  questions[questionIndex].question = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Options
            Text(
              'Options',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            ...question.options.asMap().entries.map((entry) {
              int optionIndex = entry.key;
              String optionText = entry.value;
              bool isCorrect = question.correctAnswerIndex == optionIndex;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : ThemeHelper.getBorderColor(context),
                    width: isCorrect ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isCorrect
                      ? Colors.green.withValues(alpha: 0.05)
                      : null,
                ),
                child: Row(
                  children: [
                    // Correct Answer Radio
                    Radio<int>(
                      value: optionIndex,
                      groupValue: question.correctAnswerIndex,
                      onChanged: (value) {
                        setState(() {
                          questions[questionIndex].correctAnswerIndex = value!;
                        });
                      },
                      activeColor: Colors.green,
                    ),

                    // Option Text Field
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Option ${optionIndex + 1}',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        controller: TextEditingController(text: optionText)
                          ..selection = TextSelection.fromPosition(
                            TextPosition(offset: optionText.length),
                          ),
                        onChanged: (value) {
                          setState(() {
                            questions[questionIndex].options[optionIndex] = value;
                          });
                        },
                      ),
                    ),

                    // Remove Option Button
                    if (question.options.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: Colors.red,
                        onPressed: () => _removeOption(questionIndex, optionIndex),
                      ),
                  ],
                ),
              );
            }).toList(),

            // Add Option Button
            if (question.options.length < 6)
              TextButton.icon(
                onPressed: () => _addOption(questionIndex),
                icon: const Icon(Icons.add_rounded),
                label: Text('Add Option', style: GoogleFonts.poppins(fontSize: 12)),
              ),

            // Correct Answer Hint
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Select the correct answer by clicking the radio button',
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
