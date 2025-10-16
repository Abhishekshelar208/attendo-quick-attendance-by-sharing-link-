import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateInstantDataCollectionScreen extends StatefulWidget {
  const CreateInstantDataCollectionScreen({Key? key}) : super(key: key);

  @override
  _CreateInstantDataCollectionScreenState createState() =>
      _CreateInstantDataCollectionScreenState();
}

class _CreateInstantDataCollectionScreenState
    extends State<CreateInstantDataCollectionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _collectName = true;
  bool _allowMultipleSubmissions = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _customFields = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    // Validation
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a session title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_customFields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one custom field'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create session document
      final sessionRef =
          FirebaseFirestore.instance.collection('instant_data_collection').doc();

      await sessionRef.set({
        'sessionId': sessionRef.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'teacherId': user.uid,
        'teacherEmail': user.email,
        'collectName': _collectName,
        'allowMultipleSubmissions': _allowMultipleSubmissions,
        'customFields': _customFields,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Navigate to share screen
      Navigator.pushReplacementNamed(
        context,
        '/instant-data-collection/share',
        arguments: sessionRef.id,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddCustomFieldDialog() {
    String fieldName = '';
    String fieldType = 'text';
    bool isRequired = true;
    List<String> options = [];
    final TextEditingController optionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool needsOptions = ['dropdown', 'radio', 'checkbox'].contains(fieldType);

          return AlertDialog(
            backgroundColor: ThemeHelper.getCardColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Add Custom Field',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field Name
                  TextField(
                    onChanged: (value) => fieldName = value,
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Field Name',
                      labelStyle: GoogleFonts.poppins(
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field Type
                  DropdownButtonFormField<String>(
                    value: fieldType,
                    decoration: InputDecoration(
                      labelText: 'Field Type',
                      labelStyle: GoogleFonts.poppins(
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'text', child: Text('Text', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'number', child: Text('Number', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'email', child: Text('Email', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'phone', child: Text('Phone', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'dropdown', child: Text('Dropdown', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'radio', child: Text('Radio Buttons', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'checkbox', child: Text('Checkboxes', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'yesno', child: Text('Yes/No Toggle', style: GoogleFonts.poppins())),
                      DropdownMenuItem(value: 'file', child: Text('File Upload', style: GoogleFonts.poppins())),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        fieldType = value!;
                        if (!needsOptions) {
                          options.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Options (for dropdown, radio, checkbox)
                  if (needsOptions) ...[
                    TextField(
                      controller: optionsController,
                      style: GoogleFonts.poppins(),
                      decoration: InputDecoration(
                        labelText: 'Options (comma-separated)',
                        labelStyle: GoogleFonts.poppins(
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                        hintText: 'e.g., Option 1, Option 2, Option 3',
                        hintStyle: GoogleFonts.poppins(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        options = value
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Required Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Required Field',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      Switch(
                        value: isRequired,
                        activeColor: ThemeHelper.getSuccessColor(context),
                        onChanged: (value) {
                          setDialogState(() {
                            isRequired = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (fieldName.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please enter a field name'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (needsOptions && options.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Please provide options for this field type'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _customFields.add({
                      'name': fieldName.trim(),
                      'type': fieldType,
                      'required': isRequired,
                      if (needsOptions) 'options': options,
                    });
                  });

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.getPrimaryColor(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeCustomField(int index) {
    setState(() {
      _customFields.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Create Data Collection',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: ThemeHelper.getPrimaryColor(context),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: ThemeHelper.getPrimaryColor(context),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Field
                  _buildSectionTitle('Session Title'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Enter session title',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 20),

                  // Description Field
                  _buildSectionTitle('Description (Optional)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _descriptionController,
                    hint: 'Enter description',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Settings
                  _buildSectionTitle('Settings'),
                  const SizedBox(height: 12),
                  _buildToggleOption(
                    title: 'Collect Student Names',
                    value: _collectName,
                    onChanged: (value) => setState(() => _collectName = value),
                    icon: Icons.person_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildToggleOption(
                    title: 'Allow Multiple Submissions',
                    subtitle: 'Students can submit multiple times',
                    value: _allowMultipleSubmissions,
                    onChanged: (value) =>
                        setState(() => _allowMultipleSubmissions = value),
                    icon: Icons.repeat_rounded,
                  ),
                  const SizedBox(height: 24),

                  // Custom Fields Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Custom Fields'),
                      ElevatedButton.icon(
                        onPressed: _showAddCustomFieldDialog,
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Add Field',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getPrimaryColor(context),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Custom Fields List
                  if (_customFields.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        border: Border.all(
                          color: ThemeHelper.getBorderColor(context),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'No custom fields added yet',
                          style: GoogleFonts.poppins(
                            color: ThemeHelper.getTextTertiary(context),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._customFields.asMap().entries.map((entry) {
                      final index = entry.key;
                      final field = entry.value;
                      return _buildCustomFieldCard(field, index);
                    }).toList(),

                  const SizedBox(height: 32),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeHelper.getPrimaryColor(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Create Session',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ThemeHelper.getTextPrimary(context),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ThemeHelper.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: ThemeHelper.getTextTertiary(context),
          ),
          prefixIcon: Icon(
            icon,
            color: ThemeHelper.getPrimaryColor(context),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              color: ThemeHelper.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: ThemeHelper.getPrimaryColor(context),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: ThemeHelper.getSuccessColor(context),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFieldCard(Map<String, dynamic> field, int index) {
    final fieldType = field['type'] as String;
    final fieldName = field['name'] as String;
    final isRequired = field['required'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              color: ThemeHelper.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIconForFieldType(fieldType),
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
                    Text(
                      fieldName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    if (isRequired)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '*',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  _getFieldTypeLabel(fieldType),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                ),
                if (field.containsKey('options'))
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
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_rounded,
              color: Colors.red,
              size: 20,
            ),
            onPressed: () => _removeCustomField(index),
          ),
        ],
      ),
    );
  }

  IconData _getIconForFieldType(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields_rounded;
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
      case 'file':
        return Icons.upload_file_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  String _getFieldTypeLabel(String type) {
    switch (type) {
      case 'text':
        return 'Text Input';
      case 'number':
        return 'Number Input';
      case 'email':
        return 'Email Input';
      case 'phone':
        return 'Phone Input';
      case 'dropdown':
        return 'Dropdown';
      case 'radio':
        return 'Radio Buttons';
      case 'checkbox':
        return 'Checkboxes';
      case 'yesno':
        return 'Yes/No Toggle';
      case 'file':
        return 'File Upload';
      default:
        return type;
    }
  }
}
