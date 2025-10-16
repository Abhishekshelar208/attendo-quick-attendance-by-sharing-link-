import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'ShareFeedbackScreen.dart';

class CreateFeedbackScreen extends StatefulWidget {
  const CreateFeedbackScreen({Key? key}) : super(key: key);

  @override
  _CreateFeedbackScreenState createState() => _CreateFeedbackScreenState();
}

class _CreateFeedbackScreenState extends State<CreateFeedbackScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String selectedType = 'Q&A'; // Q&A or Feedback
  List<Map<String, dynamic>> customFields = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddCustomFieldDialog() {
    final fieldNameController = TextEditingController();
    final optionsController = TextEditingController();
    String selectedFieldType = 'text';
    bool isRequired = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Custom Field', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fieldNameController,
                  decoration: InputDecoration(
                    labelText: 'Field Name',
                    hintText: 'e.g., Email, Rating, Comments',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFieldType,
                  decoration: InputDecoration(
                    labelText: 'Field Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'text', child: Row(
                      children: const [Icon(Icons.text_fields_rounded, size: 20), SizedBox(width: 8), Text('Text Input')],
                    )),
                    DropdownMenuItem(value: 'number', child: Row(
                      children: const [Icon(Icons.numbers_rounded, size: 20), SizedBox(width: 8), Text('Number')],
                    )),
                    DropdownMenuItem(value: 'email', child: Row(
                      children: const [Icon(Icons.email_rounded, size: 20), SizedBox(width: 8), Text('Email')],
                    )),
                    DropdownMenuItem(value: 'phone', child: Row(
                      children: const [Icon(Icons.phone_rounded, size: 20), SizedBox(width: 8), Text('Phone')],
                    )),
                    DropdownMenuItem(value: 'dropdown', child: Row(
                      children: const [Icon(Icons.arrow_drop_down_circle_rounded, size: 20), SizedBox(width: 8), Text('Dropdown List')],
                    )),
                    DropdownMenuItem(value: 'radio', child: Row(
                      children: const [Icon(Icons.radio_button_checked_rounded, size: 20), SizedBox(width: 8), Text('Radio Buttons')],
                    )),
                    DropdownMenuItem(value: 'checkbox', child: Row(
                      children: const [Icon(Icons.check_box_rounded, size: 20), SizedBox(width: 8), Text('Checkboxes')],
                    )),
                    DropdownMenuItem(value: 'yesno', child: Row(
                      children: const [Icon(Icons.toggle_on_rounded, size: 20), SizedBox(width: 8), Text('Yes/No')],
                    )),
                    DropdownMenuItem(value: 'rating', child: Row(
                      children: const [Icon(Icons.star_rounded, size: 20), SizedBox(width: 8), Text('Star Rating')],
                    )),
                    DropdownMenuItem(value: 'textarea', child: Row(
                      children: const [Icon(Icons.notes_rounded, size: 20), SizedBox(width: 8), Text('Long Text')],
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedFieldType = value!);
                  },
                ),
                const SizedBox(height: 16),
                // Options field for dropdown, radio, checkbox
                if (['dropdown', 'radio', 'checkbox'].contains(selectedFieldType)) ...[
                  TextField(
                    controller: optionsController,
                    decoration: InputDecoration(
                      labelText: 'Options (comma-separated)',
                      hintText: 'e.g., Excellent, Good, Average, Poor',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Separate each option with a comma',
                      helperStyle: GoogleFonts.poppins(fontSize: 11),
                    ),
                    maxLines: 2,
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                ],
                // Required checkbox
                Row(
                  children: [
                    Checkbox(
                      value: isRequired,
                      onChanged: (value) {
                        setDialogState(() => isRequired = value!);
                      },
                    ),
                    Text('Required field', style: GoogleFonts.poppins(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (fieldNameController.text.trim().isEmpty) {
                  EnhancedSnackBar.show(
                    context,
                    message: 'Please enter field name',
                    type: SnackBarType.error,
                  );
                  return;
                }
                
                // Validate options for dropdown/radio/checkbox
                if (['dropdown', 'radio', 'checkbox'].contains(selectedFieldType)) {
                  if (optionsController.text.trim().isEmpty) {
                    EnhancedSnackBar.show(
                      context,
                      message: 'Please enter options for this field type',
                      type: SnackBarType.error,
                    );
                    return;
                  }
                }
                
                Map<String, dynamic> fieldData = {
                  'name': fieldNameController.text.trim(),
                  'type': selectedFieldType,
                  'required': isRequired,
                };
                
                // Add options if applicable
                if (['dropdown', 'radio', 'checkbox'].contains(selectedFieldType)) {
                  List<String> options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  fieldData['options'] = options;
                }
                
                setState(() {
                  customFields.add(fieldData);
                });
                Navigator.pop(context);
                
                EnhancedSnackBar.show(
                  context,
                  message: 'Custom field added successfully',
                  type: SnackBarType.success,
                );
              },
              child: Text('Add Field'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFieldIcon(String type) {
    switch (type) {
      case 'number':
        return Icons.numbers_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'phone':
        return Icons.phone_rounded;
      case 'dropdown':
        return Icons.arrow_drop_down_circle_rounded;
      case 'radio':
        return Icons.radio_button_checked_rounded;
      case 'checkbox':
        return Icons.check_box_rounded;
      case 'yesno':
        return Icons.toggle_on_rounded;
      case 'rating':
        return Icons.star_rounded;
      case 'textarea':
        return Icons.notes_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  String _getFieldTypeLabel(String type) {
    switch (type) {
      case 'number':
        return 'Number Input';
      case 'email':
        return 'Email Address';
      case 'phone':
        return 'Phone Number';
      case 'dropdown':
        return 'Dropdown List';
      case 'radio':
        return 'Radio Buttons';
      case 'checkbox':
        return 'Checkboxes';
      case 'yesno':
        return 'Yes/No Toggle';
      case 'rating':
        return 'Star Rating';
      case 'textarea':
        return 'Long Text Area';
      default:
        return 'Text Input';
    }
  }

  void _createSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.getPrimaryColor(context)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Creating session...',
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

      final currentUser = FirebaseAuth.instance.currentUser;

      Map<String, dynamic> sessionData = {
        'name': _nameController.text.trim(),
        'type': selectedType, // Q&A or Feedback
        'created_at': DateTime.now().toIso8601String(),
        'creator_uid': currentUser?.uid ?? 'unknown',
        'creator_name': currentUser?.displayName ?? 'Unknown',
        'creator_email': currentUser?.email ?? '',
        'status': 'active', // active, ended
        'responses': {},
      };
      
      // Add custom fields
      if (customFields.isNotEmpty) {
        sessionData['custom_fields'] = customFields;
      }

      await dbRef.child(sessionId).set(sessionData);

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShareFeedbackScreen(sessionId: sessionId),
        ),
      );
    } catch (e) {
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
          "Create Q&A / Feedback Session",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff059669), Color(0xff10b981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff059669).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.feedback_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Collect responses, feedback, or Q&A from students with custom fields',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Type Selection
                Text(
                  'Select Type *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeCard(
                        type: 'Q&A',
                        icon: Icons.question_answer_rounded,
                        description: 'Questions & Answers',
                        color: const Color(0xff3b82f6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeCard(
                        type: 'Feedback',
                        icon: Icons.rate_review_rounded,
                        description: 'Collect Feedback',
                        color: const Color(0xff059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Session Name
                Text(
                  'Session Name *',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    border: Border.all(color: ThemeHelper.getBorderColor(context)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: selectedType == 'Q&A' 
                          ? 'e.g., Lecture Doubts, Course Feedback'
                          : 'e.g., Workshop Feedback, Event Survey',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.getTextTertiary(context),
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.title_rounded,
                        color: ThemeHelper.getPrimaryColor(context),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter session name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 32),

                // Custom Fields Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Custom Fields',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddCustomFieldDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Field'),
                      style: TextButton.styleFrom(
                        foregroundColor: ThemeHelper.getPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (customFields.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      border: Border.all(color: ThemeHelper.getBorderColor(context)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No custom fields added. Click "Add Field" to create.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...customFields.asMap().entries.map((entry) {
                    int index = entry.key;
                    Map<String, dynamic> field = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        border: Border.all(color: ThemeHelper.getBorderColor(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getFieldIcon(field['type']!),
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        field['name']!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: ThemeHelper.getTextPrimary(context),
                                        ),
                                      ),
                                    ),
                                    if (field['required'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Required',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  _getFieldTypeLabel(field['type']!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: ThemeHelper.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: ThemeHelper.getErrorColor(context),
                            onPressed: () {
                              setState(() => customFields.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 40),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createSession,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Session',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Widget _buildTypeCard({
    required String type,
    required IconData icon,
    required String description,
    required Color color,
  }) {
    bool isSelected = selectedType == type;
    
    return GestureDetector(
      onTap: () => setState(() => selectedType = type),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : ThemeHelper.getCardColor(context),
          border: Border.all(
            color: isSelected ? color : ThemeHelper.getBorderColor(context),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : ThemeHelper.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ThemeHelper.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
