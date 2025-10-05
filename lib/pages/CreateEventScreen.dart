import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'ShareEventScreen.dart';

class CreateEventScreen extends StatefulWidget {
  @override
  _CreateEventScreenState createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? selectedYear;
  String? selectedBranch;
  String? selectedDivision;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedInputType = "Roll Number";
  bool hasCapacityLimit = false;
  List<Map<String, dynamic>> customFields = []; // {name: 'Age', type: 'number', required: true, options: [...]}

  final List<String> years = ['1st Year', '2nd Year', '3rd Year', '4th Year', 'All Years'];
  final List<String> branches = ['CO', 'IT', 'AIDS', 'All Branches'];
  final List<String> divisions = ['A', 'B', 'C', 'All Divisions'];
  final List<String> inputTypes = ['Roll Number', 'Name', 'Email', 'Phone'];

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
              surface: Colors.white,
              onSurface: ThemeHelper.getTextPrimary(context),
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
              surface: Colors.white,
              onSurface: ThemeHelper.getTextPrimary(context),
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

  void createEventSession() async {
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

    if (hasCapacityLimit && (_capacityController.text.isEmpty || int.tryParse(_capacityController.text) == null)) {
      EnhancedSnackBar.show(
        context,
        message: 'Please enter a valid capacity limit',
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
                  'Creating event session...',
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
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("event_sessions");
      String sessionId = dbRef.push().key!;

      print('🎉 Creating event session...');
      print('   Event: ${_eventNameController.text}');
      print('   Venue: ${_venueController.text}');
      print('   Session ID: $sessionId');

      Map<String, dynamic> eventData = {
        'event_name': _eventNameController.text.trim(),
        'venue': _venueController.text.trim(),
        'date': DateFormat('dd MMM yyyy').format(selectedDate!),
        'time': selectedTime!.format(context),
        'year': selectedYear,
        'branch': selectedBranch,
        'division': selectedDivision,
        'input_type': selectedInputType,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'active', // active, ended
        'participants': {},
      };

      if (hasCapacityLimit) {
        eventData['capacity'] = int.parse(_capacityController.text);
      }
      
      // Add custom fields
      if (customFields.isNotEmpty) {
        eventData['custom_fields'] = customFields;
      }

      await dbRef.child(sessionId).set(eventData);

      print('✅ Event session created successfully!');
      print('   URL: https://attendo-312ea.web.app/#/event/$sessionId');

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShareEventScreen(sessionId: sessionId),
        ),
      );
    } catch (e) {
      print('❌ Error creating event: $e');
      Navigator.pop(context); // Close loading dialog
      EnhancedSnackBar.show(
        context,
        message: 'Error creating event. Please try again.',
        type: SnackBarType.error,
      );
    }
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
                    hintText: 'e.g., T-Shirt Size, Dietary Preference',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFieldType,
                  decoration: InputDecoration(
                    labelText: 'Field Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    DropdownMenuItem(value: 'text', child: Row(
                      children: [Icon(Icons.text_fields_rounded, size: 20), SizedBox(width: 8), Text('Text Input')],
                    )),
                    DropdownMenuItem(value: 'number', child: Row(
                      children: [Icon(Icons.numbers_rounded, size: 20), SizedBox(width: 8), Text('Number')],
                    )),
                    DropdownMenuItem(value: 'email', child: Row(
                      children: [Icon(Icons.email_rounded, size: 20), SizedBox(width: 8), Text('Email')],
                    )),
                    DropdownMenuItem(value: 'phone', child: Row(
                      children: [Icon(Icons.phone_rounded, size: 20), SizedBox(width: 8), Text('Phone')],
                    )),
                    DropdownMenuItem(value: 'dropdown', child: Row(
                      children: [Icon(Icons.arrow_drop_down_circle_rounded, size: 20), SizedBox(width: 8), Text('Dropdown List')],
                    )),
                    DropdownMenuItem(value: 'radio', child: Row(
                      children: [Icon(Icons.radio_button_checked_rounded, size: 20), SizedBox(width: 8), Text('Radio Buttons')],
                    )),
                    DropdownMenuItem(value: 'checkbox', child: Row(
                      children: [Icon(Icons.check_box_rounded, size: 20), SizedBox(width: 8), Text('Checkboxes')],
                    )),
                    DropdownMenuItem(value: 'yesno', child: Row(
                      children: [Icon(Icons.toggle_on_rounded, size: 20), SizedBox(width: 8), Text('Yes/No')],
                    )),
                    DropdownMenuItem(value: 'file', child: Row(
                      children: [Icon(Icons.upload_file_rounded, size: 20), SizedBox(width: 8), Text('File Upload')],
                    )),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedFieldType = value!);
                  },
                ),
                SizedBox(height: 16),
                // Options field for dropdown, radio, checkbox
                if (['dropdown', 'radio', 'checkbox'].contains(selectedFieldType)) ...[
                  TextField(
                    controller: optionsController,
                    decoration: InputDecoration(
                      labelText: 'Options (comma-separated)',
                      hintText: 'e.g., Small, Medium, Large, XL',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Separate each option with a comma',
                      helperStyle: GoogleFonts.poppins(fontSize: 11),
                    ),
                    maxLines: 2,
                    style: GoogleFonts.poppins(),
                  ),
                  SizedBox(height: 16),
                ],
                // File type selector for file upload
                if (selectedFieldType == 'file') ...[
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Supports: Images (JPG, PNG), PDFs, Docs',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
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
      case 'file':
        return Icons.upload_file_rounded;
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
      case 'file':
        return 'File Upload';
      default:
        return 'Text Input';
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          "Create Event Session",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFEC4899).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.celebration_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Create an event session. Students will scan QR code or open the link to check-in.',
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
                SizedBox(height: 32),

                // Event Name
                _buildSectionLabel('Event Name *'),
                SizedBox(height: 8),
                _buildTextField(
                  controller: _eventNameController,
                  hint: 'e.g., AI Bootcamp, Tech Fest Workshop',
                  icon: Icons.event_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter event name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // Venue
                _buildSectionLabel('Venue *'),
                SizedBox(height: 8),
                _buildTextField(
                  controller: _venueController,
                  hint: 'e.g., Auditorium, Room 301, Ground Floor',
                  icon: Icons.location_on_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter venue';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // Year & Branch
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Year *'),
                          SizedBox(height: 8),
                          _buildDropdown(
                            context,
                            value: selectedYear,
                            hint: 'Year',
                            items: years,
                            onChanged: (value) => setState(() => selectedYear = value),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Branch *'),
                          SizedBox(height: 8),
                          _buildDropdown(
                            context,
                            value: selectedBranch,
                            hint: 'Branch',
                            items: branches,
                            onChanged: (value) => setState(() => selectedBranch = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Division
                _buildSectionLabel('Division *'),
                SizedBox(height: 12),
                _buildDivisionSelector(),
                SizedBox(height: 24),

                // Date & Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Date *'),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            context,
                            icon: Icons.calendar_today_rounded,
                            label: selectedDate == null
                                ? 'Select Date'
                                : DateFormat('dd MMM yyyy').format(selectedDate!),
                            onTap: _selectDate,
                            isSelected: selectedDate != null,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Time *'),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            context,
                            icon: Icons.access_time_rounded,
                            label: selectedTime == null
                                ? 'Select Time'
                                : selectedTime!.format(context),
                            onTap: _selectTime,
                            isSelected: selectedTime != null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Capacity Limit
                Row(
                  children: [
                    Checkbox(
                      value: hasCapacityLimit,
                      onChanged: (value) => setState(() => hasCapacityLimit = value ?? false),
                      activeColor: ThemeHelper.getPrimaryColor(context),
                    ),
                    Expanded(
                      child: Text(
                        'Set capacity limit (optional)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasCapacityLimit) ...[
                  SizedBox(height: 8),
                  _buildTextField(
                    controller: _capacityController,
                    hint: 'Maximum participants (e.g., 100)',
                    icon: Icons.people_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
                SizedBox(height: 24),

                // Input Type
                _buildSectionLabel('Participant Input Type *'),
                SizedBox(height: 12),
                _buildInputTypeSelector(),
                SizedBox(height: 32),

                // Custom Fields Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel('Custom Fields (Optional)'),
                    TextButton.icon(
                      onPressed: _showAddCustomFieldDialog,
                      icon: Icon(Icons.add_circle_outline_rounded),
                      label: Text('Add Field'),
                      style: TextButton.styleFrom(
                        foregroundColor: ThemeHelper.getPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (customFields.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20),
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
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        border: Border.all(color: ThemeHelper.getBorderColor(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
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
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field['name']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeHelper.getTextPrimary(context),
                                  ),
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
                            icon: Icon(Icons.delete_outline_rounded),
                            color: ThemeHelper.getErrorColor(context),
                            onPressed: () {
                              setState(() => customFields.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                SizedBox(height: 40),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: createEventSession,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Event Session',
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

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ThemeHelper.getTextPrimary(context),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ThemeHelper.getTextPrimary(context),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: ThemeHelper.getTextTertiary(context),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: ThemeHelper.getTextSecondary(context), size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.getTextTertiary(context),
            ),
          ),
          isExpanded: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDivisionSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: divisions.map((div) {
        bool isSelected = selectedDivision == div;
        return GestureDetector(
          onTap: () => setState(() => selectedDivision = div),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeHelper.getPrimaryColor(context)
                  : ThemeHelper.getCardColor(context),
              border: Border.all(
                color: isSelected
                    ? ThemeHelper.getPrimaryColor(context)
                    : ThemeHelper.getBorderColor(context),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              div,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : ThemeHelper.getTextSecondary(context),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          border: Border.all(
            color: isSelected
                ? ThemeHelper.getPrimaryColor(context)
                : ThemeHelper.getBorderColor(context),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? ThemeHelper.getPrimaryColor(context)
                  : ThemeHelper.getTextSecondary(context),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? ThemeHelper.getTextPrimary(context)
                      : ThemeHelper.getTextTertiary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTypeSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: inputTypes.map((type) {
        bool isSelected = selectedInputType == type;
        IconData icon = type == 'Roll Number'
            ? Icons.numbers_rounded
            : type == 'Name'
                ? Icons.person_rounded
                : type == 'Email'
                    ? Icons.email_rounded
                    : Icons.phone_rounded;

        return GestureDetector(
          onTap: () => setState(() => selectedInputType = type),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                  : ThemeHelper.getCardColor(context),
              border: Border.all(
                color: isSelected
                    ? ThemeHelper.getPrimaryColor(context)
                    : ThemeHelper.getBorderColor(context),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? ThemeHelper.getPrimaryColor(context)
                      : ThemeHelper.getTextSecondary(context),
                ),
                SizedBox(width: 8),
                Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? ThemeHelper.getPrimaryColor(context)
                        : ThemeHelper.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
