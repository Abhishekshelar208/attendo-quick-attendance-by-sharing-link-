import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/models/quiz_models.dart';
import 'package:attendo/pages/QuizQuestionsScreen.dart';
import 'package:attendo/pages/AIQuizGeneratorScreen.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({Key? key}) : super(key: key);

  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController _quizNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? selectedYear;
  String? selectedBranch;
  String? selectedDivision;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedQuizType = 'MCQ';

  // Only Name field is required for quiz participants
  List<CustomField> customFields = [
    CustomField(name: 'Name', required: true),
  ];

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> branches = ['CO', 'IT', 'AIDS', 'MECH', 'CIVIL'];
  final List<String> divisions = ['A', 'B', 'C', 'D'];
  final List<String> quizTypes = ['MCQ', 'True/False', 'Short Answer', 'Essay'];

  @override
  void dispose() {
    _quizNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeHelper.getPrimaryColor(context),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeHelper.getPrimaryColor(context),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  void _addCustomField() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Add Custom Field', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Field Name',
              hintText: 'e.g., Roll Number, Email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    customFields.add(CustomField(name: controller.text.trim()));
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Add', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  void _removeCustomField(int index) {
    if (index >= 2) { // Can't remove Name and Student ID
      setState(() {
        customFields.removeAt(index);
      });
    }
  }

  void _proceedToQuestionCreation(String method) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedYear == null ||
        selectedBranch == null ||
        selectedDivision == null ||
        selectedDate == null ||
        selectedTime == null) {
      EnhancedSnackBar.show(
        context,
        message: 'Please fill all required fields',
        type: SnackBarType.error,
      );
      return;
    }

    // Create quiz data object to pass to next screen
    final quizData = {
      'quiz_name': _quizNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'year': selectedYear,
      'branch': selectedBranch,
      'division': selectedDivision,
      'date': DateFormat('dd MMM yyyy').format(selectedDate!),
      'time': selectedTime!.format(context),
      'quiz_type': selectedQuizType,
      'custom_fields': customFields,
    };

    if (method == 'manual') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizQuestionsScreen(quizData: quizData),
        ),
      );
    } else if (method == 'ai') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIQuizGeneratorScreen(quizData: quizData),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Create Quiz',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.getPrimaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.quiz_rounded, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Create an interactive quiz for your students',
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

                // Quiz Name
                Text(
                  'Quiz Name *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _quizNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Math Chapter 5 Quiz',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Quiz name is required' : null,
                ),
                const SizedBox(height: 20),

                // Description
                Text(
                  'Description',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Brief description of the quiz (optional)',
                    prefixIcon: const Icon(Icons.description_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Year
                Text(
                  'Year *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.school_rounded),
                  ),
                  hint: const Text('Select Year'),
                  items: years.map((year) {
                    return DropdownMenuItem(value: year, child: Text(year));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedYear = value),
                ),
                const SizedBox(height: 20),

                // Branch
                Text(
                  'Branch *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedBranch,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.engineering_rounded),
                  ),
                  hint: const Text('Select Branch'),
                  items: branches.map((branch) {
                    return DropdownMenuItem(value: branch, child: Text(branch));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedBranch = value),
                ),
                const SizedBox(height: 20),

                // Division
                Text(
                  'Division *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDivision,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.people_rounded),
                  ),
                  hint: const Text('Select Division'),
                  items: divisions.map((div) {
                    return DropdownMenuItem(value: div, child: Text(div));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedDivision = value),
                ),
                const SizedBox(height: 20),

                // Date and Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date *',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: ThemeHelper.getBorderColor(context)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 20, color: ThemeHelper.getPrimaryColor(context)),
                                  const SizedBox(width: 12),
                                  Text(
                                    selectedDate == null
                                        ? 'Select Date'
                                        : DateFormat('dd MMM yyyy').format(selectedDate!),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
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
                            'Time *',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: ThemeHelper.getBorderColor(context)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 20, color: ThemeHelper.getPrimaryColor(context)),
                                  const SizedBox(width: 12),
                                  Text(
                                    selectedTime == null
                                        ? 'Select Time'
                                        : selectedTime!.format(context),
                                    style: GoogleFonts.poppins(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Student will only need to enter their Name
                // No additional custom fields needed
                const SizedBox(height: 24),

                // Quiz Type Selection
                Text(
                  'Quiz Type *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                ...quizTypes.asMap().entries.map((entry) {
                  int index = entry.key;
                  String type = entry.value;
                  bool isEnabled = type == 'MCQ';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<String>(
                      value: type,
                      groupValue: selectedQuizType,
                      onChanged: isEnabled ? (value) => setState(() => selectedQuizType = value!) : null,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isEnabled
                                    ? ThemeHelper.getTextPrimary(context)
                                    : ThemeHelper.getTextTertiary(context),
                              ),
                            ),
                          ),
                          if (!isEnabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Soon',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getWarningColor(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: ThemeHelper.getCardColor(context),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 32),

                // Proceed Buttons
                Text(
                  'Choose Question Creation Method',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Manual Entry Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _proceedToQuestionCreation('manual'),
                    icon: const Icon(Icons.edit_rounded),
                    label: Text(
                      'Create Questions Manually',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // AI Generation Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () => _proceedToQuestionCreation('ai'),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      'Generate with AI (Gemini)',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: ThemeHelper.getPrimaryColor(context), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
