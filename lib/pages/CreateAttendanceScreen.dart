import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'ShareAttendanceScreen.dart';

class CreateAttendanceScreen extends StatefulWidget {
  @override
  _CreateAttendanceScreenState createState() => _CreateAttendanceScreenState();
}

class _CreateAttendanceScreenState extends State<CreateAttendanceScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String? selectedYear;
  String? selectedBranch;
  String? selectedDivision;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedType = "Roll Number";

  final List<String> years = ['2nd Year', '3rd Year', '4th Year'];
  final List<String> branches = ['CO', 'IT', 'AIDS'];
  final List<String> divisions = ['A', 'B', 'C'];
  final List<String> types = ['Roll Number', 'Name'];

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
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
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
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

  void createAttendanceSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedYear == null ||
        selectedBranch == null ||
        selectedDivision == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
                SizedBox(height: 16),
                Text(
                  'Creating session...',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("attendance_sessions");
      String sessionId = dbRef.push().key!;

      await dbRef.child(sessionId).set({
        'subject': _subjectController.text.trim(),
        'date': DateFormat('dd MMM yyyy').format(selectedDate!),
        'time': selectedTime!.format(context),
        'year': selectedYear,
        'branch': selectedBranch,
        'division': selectedDivision,
        'type': selectedType,
        'created_at': DateTime.now().toIso8601String(),
        'students': {},
      });

      Navigator.pop(context); // Close loading dialog
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ShareAttendanceScreen(sessionId: sessionId),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating session. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Create Session",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  "Session Details",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Fill in the information below to create a new attendance session",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 32),

                // Subject Name
                _buildSectionLabel("Subject", true),
                SizedBox(height: 8),
                TextFormField(
                  controller: _subjectController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter subject name",
                    hintStyle: GoogleFonts.inter(
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: Icon(Icons.book_rounded, color: Color(0xFF6366F1)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter subject name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 24),

                // Year, Branch, Division Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("Year", true),
                          SizedBox(height: 8),
                          _buildDropdown(
                            value: selectedYear,
                            items: years,
                            hint: "Select",
                            icon: Icons.school_rounded,
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
                          _buildSectionLabel("Branch", true),
                          SizedBox(height: 8),
                          _buildDropdown(
                            value: selectedBranch,
                            items: branches,
                            hint: "Select",
                            icon: Icons.apartment_rounded,
                            onChanged: (value) => setState(() => selectedBranch = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Division
                _buildSectionLabel("Division", true),
                SizedBox(height: 8),
                _buildDivisionSelector(),
                SizedBox(height: 24),

                // Date and Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel("Date", true),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            icon: Icons.calendar_today_rounded,
                            text: selectedDate != null
                                ? DateFormat('dd MMM yyyy').format(selectedDate!)
                                : 'Select date',
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
                          _buildSectionLabel("Time", true),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            icon: Icons.access_time_rounded,
                            text: selectedTime != null
                                ? selectedTime!.format(context)
                                : 'Select time',
                            onTap: _selectTime,
                            isSelected: selectedTime != null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Type Selection
                _buildSectionLabel("Attendance Type", true),
                SizedBox(height: 8),
                _buildTypeSelector(),
                SizedBox(height: 40),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: createAttendanceSession,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: Text(
                      "Create Attendance Session",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool required) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(color: Color(0xFFEF4444), fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.inter(color: Color(0xFF94A3B8), fontSize: 15),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Color(0xFF1E293B),
          ),
          dropdownColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDivisionSelector() {
    return Row(
      children: divisions.map((division) {
        bool isSelected = selectedDivision == division;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: division != divisions.last ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => selectedDivision = division),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF6366F1) : Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    division,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateTimeTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Color(0xFF6366F1) : Color(0xFF64748B),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isSelected ? Color(0xFF1E293B) : Color(0xFF94A3B8),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: types.map((type) {
        bool isSelected = selectedType == type;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: type != types.last ? 12 : 0),
            child: InkWell(
              onTap: () => setState(() => selectedType = type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Color(0xFF6366F1).withOpacity(0.1) : Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == 'Roll Number' ? Icons.tag_rounded : Icons.person_rounded,
                      size: 20,
                      color: isSelected ? Color(0xFF6366F1) : Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Text(
                      type,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Color(0xFF6366F1) : Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
