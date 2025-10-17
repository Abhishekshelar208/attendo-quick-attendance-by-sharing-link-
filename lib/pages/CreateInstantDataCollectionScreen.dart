import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'ShareInstantDataScreen.dart';

class CreateInstantDataCollectionScreen extends StatefulWidget {
  const CreateInstantDataCollectionScreen({Key? key}) : super(key: key);

  @override
  _CreateInstantDataCollectionScreenState createState() => _CreateInstantDataCollectionScreenState();
}

class _CreateInstantDataCollectionScreenState extends State<CreateInstantDataCollectionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  List<Map<String, dynamic>> customFields = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
                    hintText: 'e.g., Student ID, Email, Department',
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
                      hintText: 'e.g., IT, CS, Mechanical, Civil',
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

    if (customFields.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'Please add at least one custom field',
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.getPrimaryColor(context)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Creating data collection session...',
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
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("instant_data_collection");
      String sessionId = dbRef.push().key!;

      final currentUser = FirebaseAuth.instance.currentUser;

      Map<String, dynamic> sessionData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'creator_uid': currentUser?.uid ?? 'unknown',
        'creator_name': currentUser?.displayName ?? 'Unknown',
        'creator_email': currentUser?.email ?? '',
        'status': 'active', // active, ended
        'custom_fields': customFields,
        'responses': {},
      };

      await dbRef.child(sessionId).set(sessionData);

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShareInstantDataScreen(sessionId: sessionId),
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
          "Instant Data Collection",
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
                      colors: [Color(0xfff59e0b), Color(0xfffbbf24)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xfff59e0b).withValues(alpha: 0.3),
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
                          Icons.poll_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Collect any data from students with custom fields - surveys, forms, or quick polls',
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

                // Session Title
                Text(
                  'Collection Title *',
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
                    controller: _titleController,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g., Student Details Survey, Workshop Registration',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.getTextTertiary(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Description (Optional)
                Text(
                  'Description (Optional)',
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
                    controller: _descriptionController,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add instructions or additional information',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ThemeHelper.getTextTertiary(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 32),

                // Custom Fields Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Custom Fields *',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${customFields.length} fields',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xfff59e0b),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Add Field Button
                InkWell(
                  onTap: _showAddCustomFieldDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      border: Border.all(
                        color: const Color(0xfff59e0b).withValues(alpha: 0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          color: const Color(0xfff59e0b),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Custom Field',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xfff59e0b),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Display Custom Fields
                if (customFields.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getTextTertiary(context).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 40,
                            color: ThemeHelper.getTextTertiary(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No fields added yet',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add at least one field to continue',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: ThemeHelper.getTextTertiary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // List of Custom Fields
                ...customFields.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> field = entry.value;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getFieldIcon(field['type']),
                            color: const Color(0xfff59e0b),
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
                                  Text(
                                    field['name'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                  if (field['required']) ...[ 
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ThemeHelper.getErrorColor(context).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Required',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: ThemeHelper.getErrorColor(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getFieldTypeLabel(field['type']),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                              if (field.containsKey('options')) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Options: ${(field['options'] as List).join(', ')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: ThemeHelper.getTextTertiary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: ThemeHelper.getErrorColor(context),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => customFields.removeAt(index));
                            EnhancedSnackBar.show(
                              context,
                              message: 'Field removed',
                              type: SnackBarType.info,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),

                const SizedBox(height: 32),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff59e0b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Create Data Collection',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
