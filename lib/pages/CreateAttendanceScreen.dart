import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:attendo/utils/theme_helper.dart';
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
  bool bluetoothAttendance = false; // Default to false (disabled)

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
              primary: Color(0xff2563eb),
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
              primary: Color(0xff2563eb),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff2563eb)),
                ),
                SizedBox(height: 16),
                Text(
                  'Creating attendance...',
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

      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Generate random 4-digit OTP
      String otp = (Random().nextInt(9000) + 1000).toString();
      
      await dbRef.child(sessionId).set({
        'subject': _subjectController.text.trim(),
        'date': DateFormat('dd MMM yyyy').format(selectedDate!),
        'time': selectedTime!.format(context),
        'year': selectedYear,
        'branch': selectedBranch,
        'division': selectedDivision,
        'type': selectedType,
        'bluetooth_enabled': bluetoothAttendance, // NEW: Bluetooth toggle
        'created_at': DateTime.now().toIso8601String(),
        'creator_uid': currentUser?.uid ?? 'unknown',
        'creator_name': currentUser?.displayName ?? 'Unknown',
        'creator_email': currentUser?.email ?? '',
        'students': {},
        'otp': otp,
        'otp_active': false,
        'otp_start_time': null,
        'bluetooth_active': false, // NEW: For when Bluetooth is activated
        'cheating_flags': {},
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
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          "Create Attendance Session",
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
                    gradient: ThemeHelper.getPrimaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
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
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Fill in the details carefully. Students will use the shared link to mark attendance.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // Form Title
                Text(
                  "Session Information",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "All fields marked with * are required",
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 32),

                // Subject Name
                _buildSectionLabel(context, "Subject Name", true),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _subjectController,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g., Data Structures, Mathematics",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.getTextTertiary(context),
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.book_rounded,
                        color: ThemeHelper.getPrimaryColor(context),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter subject name';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 24),

                // Year, Branch, Division Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(context, "Year", true),
                          SizedBox(height: 8),
                          _buildDropdown(
                            context,
                            value: selectedYear,
                            items: years,
                            hint: "Year",
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
                          _buildSectionLabel(context, "Branch", true),
                          SizedBox(height: 8),
                          _buildDropdown(
                            context,
                            value: selectedBranch,
                            items: branches,
                            hint: "Branch",
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
                _buildSectionLabel(context, "Division", true),
                SizedBox(height: 8),
                _buildDivisionSelector(context),
                SizedBox(height: 24),

                // Date and Time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(context, "Date", true),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            context,
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
                          _buildSectionLabel(context, "Time", true),
                          SizedBox(height: 8),
                          _buildDateTimeTile(
                            context,
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
                _buildSectionLabel(context, "Attendance Type", true),
                SizedBox(height: 8),
                _buildTypeSelector(context),
                SizedBox(height: 24),

                // Bluetooth Attendance Toggle
                _buildSectionLabel(context, "Bluetooth Attendance", false),
                SizedBox(height: 8),
                _buildBluetoothToggle(context),
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

  Widget _buildSectionLabel(BuildContext context, String label, bool required) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ThemeHelper.getTextPrimary(context),
          ),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(
              color: ThemeHelper.getErrorColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context),
          width: 1,
        ),
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
          isExpanded: true,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(
              color: ThemeHelper.getTextTertiary(context),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ThemeHelper.getTextSecondary(context),
          ),
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: ThemeHelper.getTextPrimary(context),
          ),
          dropdownColor: ThemeHelper.getCardColor(context),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

  Widget _buildDivisionSelector(BuildContext context) {
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
                padding: EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeHelper.getPrimaryColor(context)
                      : ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? ThemeHelper.getPrimaryColor(context)
                        : ThemeHelper.getBorderColor(context),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ThemeHelper.getPrimaryColor(context)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    division,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : ThemeHelper.getTextSecondary(context),
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

  Widget _buildDateTimeTile(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ThemeHelper.getPrimaryColor(context)
                : ThemeHelper.getBorderColor(context),
            width: isSelected ? 2 : 1,
          ),
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
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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

  Widget _buildTypeSelector(BuildContext context) {
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
                padding: EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                      : ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? ThemeHelper.getPrimaryColor(context)
                        : ThemeHelper.getBorderColor(context),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == 'Roll Number'
                          ? Icons.tag_rounded
                          : Icons.person_rounded,
                      size: 22,
                      color: isSelected
                          ? ThemeHelper.getPrimaryColor(context)
                          : ThemeHelper.getTextSecondary(context),
                    ),
                    SizedBox(width: 10),
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
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showBluetoothConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bluetooth_rounded,
                  color: ThemeHelper.getPrimaryColor(context),
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Enable Bluetooth?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to enable Bluetooth proximity verification?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Students will need to physically connect to your device to mark attendance.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextSecondary(context),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  bluetoothAttendance = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeHelper.getPrimaryColor(context),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Yes, Enable',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBluetoothToggle(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bluetoothAttendance 
              ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3)
              : ThemeHelper.getBorderColor(context),
          width: bluetoothAttendance ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: bluetoothAttendance 
                ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: bluetoothAttendance ? 8 : 4,
            offset: Offset(0, bluetoothAttendance ? 4 : 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bluetoothAttendance 
                      ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  bluetoothAttendance 
                      ? Icons.bluetooth_rounded 
                      : Icons.bluetooth_disabled_rounded,
                  color: bluetoothAttendance 
                      ? ThemeHelper.getPrimaryColor(context)
                      : Colors.grey,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth Proximity Check',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      bluetoothAttendance 
                          ? 'Students must be near you to mark attendance'
                          : 'Only OTP verification required',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ThemeHelper.getTextSecondary(context),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: bluetoothAttendance,
                onChanged: (value) {
                  if (value) {
                    // Show confirmation dialog when enabling
                    _showBluetoothConfirmationDialog(context);
                  } else {
                    // Disable directly without confirmation
                    setState(() {
                      bluetoothAttendance = value;
                    });
                  }
                },
                activeColor: ThemeHelper.getPrimaryColor(context),
                activeTrackColor: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
              ),
            ],
          ),
          if (bluetoothAttendance) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your device will be renamed to "Attendo: Teachers Device" when activated',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Students can mark attendance from anywhere with just OTP',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
