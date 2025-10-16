import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'ShareFeedbackScreen.dart';

class CreateFeedbackScreen extends StatefulWidget {
  @override
  _CreateFeedbackScreenState createState() => _CreateFeedbackScreenState();
}

class _CreateFeedbackScreenState extends State<CreateFeedbackScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _characterLimitController = TextEditingController(text: '500');
  final _formKey = GlobalKey<FormState>();
  
  String? selectedYear;
  String? selectedBranch;
  String? selectedDivision;
  String sessionType = "Feedback"; // Feedback or Q&A
  bool collectNames = true;
  bool allowMultipleSubmissions = false;
  bool hasCharacterLimit = true;

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'All Years'];
  final List<String> branches = ['CO', 'IT', 'AIDS', 'All Branches'];
  final List<String> divisions = ['A', 'B', 'C', 'All Divisions'];
  final List<String> sessionTypes = ['Feedback', 'Q&A'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _characterLimitController.dispose();
    super.dispose();
  }

  void createFeedbackSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedYear == null || selectedBranch == null || selectedDivision == null) {
      EnhancedSnackBar.show(
        context,
        message: 'Please fill all required fields',
        type: SnackBarType.error,
      );
      return;
    }

    if (hasCharacterLimit && (_characterLimitController.text.isEmpty || int.tryParse(_characterLimitController.text) == null)) {
      EnhancedSnackBar.show(
        context,
        message: 'Please enter a valid character limit',
        type: SnackBarType.error,
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.getPrimaryColor(context)),
                ),
                SizedBox(height: 16),
                Text(
                  'Creating $sessionType session...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("feedback_sessions");
      String sessionId = dbRef.push().key!;

      print('📝 Creating $sessionType session...');
      print('   Title: ${_titleController.text}');
      print('   Session ID: $sessionId');
      print('   Collect Names: $collectNames');

      final currentUser = FirebaseAuth.instance.currentUser;

      Map<String, dynamic> sessionData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'session_type': sessionType,
        'year': selectedYear,
        'branch': selectedBranch,
        'division': selectedDivision,
        'collect_names': collectNames,
        'allow_multiple_submissions': allowMultipleSubmissions,
        'created_at': DateTime.now().toIso8601String(),
        'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
        'time': TimeOfDay.now().format(context),
        'creator_uid': currentUser?.uid ?? 'unknown',
        'creator_name': currentUser?.displayName ?? 'Unknown',
        'creator_email': currentUser?.email ?? '',
        'status': 'active', // active, ended
        'submissions': {},
        'blocked_devices': {}, // Store blocked device IDs
      };

      if (hasCharacterLimit) {
        sessionData['character_limit'] = int.parse(_characterLimitController.text);
      }

      await dbRef.child(sessionId).set(sessionData);

      print('✅ $sessionType session created successfully!');
      print('   URL: https://attendo-312ea.web.app/#/feedback/$sessionId');

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShareFeedbackScreen(sessionId: sessionId),
        ),
      );
    } catch (e) {
      print('❌ Error creating session: $e');
      Navigator.pop(context); // Close loading dialog
      EnhancedSnackBar.show(
        context,
        message: 'Error creating session. Please try again.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Create ${sessionType} Session',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Session Type Selection
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getShadowColor(context),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Type',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: sessionTypes.map((type) {
                          bool isSelected = sessionType == type;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: type == sessionTypes.first ? 8 : 0),
                              child: GestureDetector(
                                onTap: () => setState(() => sessionType = type),
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? ThemeHelper.getPrimaryColor(context)
                                        : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? ThemeHelper.getPrimaryColor(context)
                                          : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        type == 'Feedback' ? Icons.rate_review_rounded : Icons.question_answer_rounded,
                                        color: isSelected ? Colors.white : ThemeHelper.getPrimaryColor(context),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        type,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : ThemeHelper.getPrimaryColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Session Title *',
                    hintText: 'e.g., Lecture Feedback, Ask Questions',
                    prefixIcon: Icon(Icons.title_rounded, color: ThemeHelper.getPrimaryColor(context)),
                    filled: true,
                    fillColor: ThemeHelper.getCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getPrimaryColor(context), width: 2),
                    ),
                  ),
                  validator: (value) => value?.trim().isEmpty ?? true ? 'Please enter a title' : null,
                ),
                
                SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add instructions or context for students',
                    prefixIcon: Icon(Icons.description_rounded, color: ThemeHelper.getPrimaryColor(context)),
                    filled: true,
                    fillColor: ThemeHelper.getCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getPrimaryColor(context), width: 2),
                    ),
                  ),
                ),
                
                SizedBox(height: 16),

                // Year Dropdown
                DropdownButtonFormField<String>(
                  value: selectedYear,
                  decoration: InputDecoration(
                    labelText: 'Year *',
                    prefixIcon: Icon(Icons.school_rounded, color: ThemeHelper.getPrimaryColor(context)),
                    filled: true,
                    fillColor: ThemeHelper.getCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                    ),
                  ),
                  items: years.map((year) {
                    return DropdownMenuItem(value: year, child: Text(year));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedYear = value),
                ),
                
                SizedBox(height: 16),

                // Branch Dropdown
                DropdownButtonFormField<String>(
                  value: selectedBranch,
                  decoration: InputDecoration(
                    labelText: 'Branch *',
                    prefixIcon: Icon(Icons.account_tree_rounded, color: ThemeHelper.getPrimaryColor(context)),
                    filled: true,
                    fillColor: ThemeHelper.getCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                    ),
                  ),
                  items: branches.map((branch) {
                    return DropdownMenuItem(value: branch, child: Text(branch));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedBranch = value),
                ),
                
                SizedBox(height: 16),

                // Division Dropdown
                DropdownButtonFormField<String>(
                  value: selectedDivision,
                  decoration: InputDecoration(
                    labelText: 'Division *',
                    prefixIcon: Icon(Icons.group_rounded, color: ThemeHelper.getPrimaryColor(context)),
                    filled: true,
                    fillColor: ThemeHelper.getCardColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                    ),
                  ),
                  items: divisions.map((division) {
                    return DropdownMenuItem(value: division, child: Text(division));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedDivision = value),
                ),
                
                SizedBox(height: 24),

                // Settings Card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getShadowColor(context),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Collect Names Toggle
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: collectNames
                              ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                              : ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: collectNames
                                ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3)
                                : ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              collectNames ? Icons.person_rounded : Icons.person_off_rounded,
                              color: collectNames
                                  ? ThemeHelper.getPrimaryColor(context)
                                  : ThemeHelper.getWarningColor(context),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Collect Student Names',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    collectNames
                                        ? 'Students will enter their name'
                                        : 'Anonymous submissions (device tracking enabled)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: collectNames,
                              onChanged: (value) => setState(() => collectNames = value),
                              activeColor: ThemeHelper.getPrimaryColor(context),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 12),

                      // Allow Multiple Submissions Toggle
                      SwitchListTile(
                        title: Text(
                          'Allow Multiple Submissions',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          'Students can submit more than once',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        value: allowMultipleSubmissions,
                        onChanged: (value) => setState(() => allowMultipleSubmissions = value),
                        activeColor: ThemeHelper.getPrimaryColor(context),
                        contentPadding: EdgeInsets.zero,
                      ),

                      Divider(),

                      // Character Limit Toggle
                      SwitchListTile(
                        title: Text(
                          'Set Character Limit',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        value: hasCharacterLimit,
                        onChanged: (value) => setState(() => hasCharacterLimit = value),
                        activeColor: ThemeHelper.getPrimaryColor(context),
                        contentPadding: EdgeInsets.zero,
                      ),

                      if (hasCharacterLimit) ...[
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _characterLimitController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Maximum Characters',
                            hintText: '500',
                            prefixIcon: Icon(Icons.text_fields_rounded, color: ThemeHelper.getPrimaryColor(context)),
                            filled: true,
                            fillColor: ThemeHelper.getBackgroundColor(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (hasCharacterLimit && (value?.trim().isEmpty ?? true)) {
                              return 'Please enter character limit';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // Create Button
                ElevatedButton(
                  onPressed: createFeedbackSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getPrimaryColor(context),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_rounded, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Create $sessionType Session',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
