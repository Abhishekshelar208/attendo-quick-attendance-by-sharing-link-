import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/models/quiz_models.dart';
import 'package:attendo/pages/ShareQuizScreen.dart';

class AIQuizGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const AIQuizGeneratorScreen({Key? key, required this.quizData}) : super(key: key);

  @override
  _AIQuizGeneratorScreenState createState() => _AIQuizGeneratorScreenState();
}

class _AIQuizGeneratorScreenState extends State<AIQuizGeneratorScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _questionCountController = TextEditingController(text: '5');
  final _formKey = GlobalKey<FormState>();

  String selectedDifficulty = 'Medium';
  final List<String> difficulties = ['Easy', 'Medium', 'Hard'];

  bool isGenerating = false;
  bool hasGenerated = false;
  List<QuizQuestion> generatedQuestions = [];

  // TODO: Replace with your Gemini API Key
  // Get it from: https://makersuite.google.com/app/apikey
  static const String GEMINI_API_KEY = 'AIzaSyAjpqxtmsOxHzQVS2yiv3wem6pqjZ6KSt8';

  Future<void> _generateWithAI() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (GEMINI_API_KEY == 'YOUR_API_KEY_HERE') {
      EnhancedSnackBar.show(
        context,
        message: 'Please configure Gemini API Key in AIQuizGeneratorScreen.dart',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() {
      isGenerating = true;
      generatedQuestions = [];
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: GEMINI_API_KEY,
      );

      final questionCount = int.parse(_questionCountController.text);
      
      final prompt = '''
Generate $questionCount multiple choice questions for a quiz with the following details:

Subject/Domain: ${_subjectController.text}
Topic: ${_topicController.text}
Difficulty Level: $selectedDifficulty

IMPORTANT: Return ONLY a valid JSON array without any markdown formatting, code blocks, or additional text. The response must start with [ and end with ].

Format your response exactly as shown below:
[
  {
    "question": "Question text here?",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer": 0
  }
]

Rules:
1. Each question should have 4 options
2. The correct_answer is the index (0-3) of the correct option
3. Make questions clear and relevant to the topic
4. Vary the difficulty based on the level specified
5. Do NOT include any explanations or additional text
6. Return ONLY the JSON array
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (response.text != null) {
        print('🤖 AI Response: ${response.text}');
        
        // Clean the response
        String jsonText = response.text!.trim();
        
        // Remove markdown code blocks if present
        jsonText = jsonText.replaceAll('```json', '').replaceAll('```', '').trim();
        
        // Parse JSON
        final List<dynamic> questionsJson = jsonDecode(jsonText);
        
        final questions = questionsJson.map((q) {
          return QuizQuestion(
            question: q['question'] as String,
            options: List<String>.from(q['options'] as List),
            correctAnswerIndex: q['correct_answer'] as int,
          );
        }).toList();

        setState(() {
          generatedQuestions = questions;
          hasGenerated = true;
          isGenerating = false;
        });

        EnhancedSnackBar.show(
          context,
          message: 'Questions generated successfully! 🎉',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      print('❌ Error generating quiz: $e');
      setState(() => isGenerating = false);
      
      EnhancedSnackBar.show(
        context,
        message: 'Error generating quiz: ${e.toString()}',
        type: SnackBarType.error,
      );
    }
  }

  void _editQuestion(int index) {
    final question = generatedQuestions[index];
    final questionController = TextEditingController(text: question.question);
    final optionControllers = question.options.map((o) => TextEditingController(text: o)).toList();
    int selectedCorrect = question.correctAnswerIndex;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Question ${index + 1}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  decoration: InputDecoration(
                    labelText: 'Question',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ...optionControllers.asMap().entries.map((entry) {
                  int i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: selectedCorrect,
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCorrect = value!;
                            });
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: 'Option ${i + 1}',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  generatedQuestions[index] = QuizQuestion(
                    question: questionController.text,
                    options: optionControllers.map((c) => c.text).toList(),
                    correctAnswerIndex: selectedCorrect,
                  );
                });
                Navigator.pop(context);
              },
              child: Text('Save', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteQuestion(int index) {
    setState(() {
      generatedQuestions.removeAt(index);
    });
  }

  Future<void> _createQuiz() async {
    if (generatedQuestions.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'Please generate questions first',
        type: SnackBarType.warning,
      );
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
        generationMethod: 'ai',
        customFields: List<CustomField>.from(widget.quizData['custom_fields']),
        questions: generatedQuestions,
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
          'AI Quiz Generator',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Info Card
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
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Let AI generate quiz questions for you using Gemini',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (!hasGenerated) ...[
                      // Subject/Domain
                      Text(
                        'Subject/Domain *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Mathematics, Physics, History',
                          prefixIcon: const Icon(Icons.school_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Subject is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Topic
                      Text(
                        'Topic/Description *',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _topicController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g., Quadratic equations and their properties',
                          prefixIcon: const Icon(Icons.description_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) => value?.isEmpty ?? true ? 'Topic is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Number of Questions & Difficulty
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Number of Questions *',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeHelper.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _questionCountController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '5',
                                    prefixIcon: const Icon(Icons.numbers_rounded),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Required';
                                    final num = int.tryParse(value!);
                                    if (num == null || num < 1 || num > 20) {
                                      return '1-20 only';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Difficulty *',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeHelper.getTextPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: selectedDifficulty,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  items: difficulties.map((diff) {
                                    return DropdownMenuItem(value: diff, child: Text(diff));
                                  }).toList(),
                                  onChanged: (value) => setState(() => selectedDifficulty = value!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Generate Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: isGenerating ? null : _generateWithAI,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            isGenerating ? 'Generating...' : 'Generate Questions with AI',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff8b5cf6),
                          ),
                        ),
                      ),
                    ],

                    if (hasGenerated) ...[
                      // Generated Questions
                      Row(
                        children: [
                          Text(
                            'Generated Questions',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                hasGenerated = false;
                                generatedQuestions = [];
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text('Regenerate', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      ...generatedQuestions.asMap().entries.map((entry) {
                        int index = entry.key;
                        QuizQuestion q = entry.value;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xff8b5cf6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Q${index + 1}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, size: 20),
                                      onPressed: () => _editQuestion(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, size: 20),
                                      color: Colors.red,
                                      onPressed: () => _deleteQuestion(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q.question,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...q.options.asMap().entries.map((optEntry) {
                                  int optIndex = optEntry.key;
                                  String option = optEntry.value;
                                  bool isCorrect = optIndex == q.correctAnswerIndex;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCorrect
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : ThemeHelper.getCardColor(context),
                                      border: Border.all(
                                        color: isCorrect ? Colors.green : ThemeHelper.getBorderColor(context),
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        if (isCorrect)
                                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                        if (isCorrect) const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: GoogleFonts.poppins(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 24),
                      
                      // Create Quiz Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isGenerating ? null : _createQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeHelper.getPrimaryColor(context),
                          ),
                          child: Text(
                            'Create Quiz',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (isGenerating && !hasGenerated)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: const Color(0xff8b5cf6)),
                        const SizedBox(height: 16),
                        Text(
                          'AI is generating questions...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: ThemeHelper.getTextSecondary(context),
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
}
