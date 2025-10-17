import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/widgets/custom_field_widgets.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'package:lottie/lottie.dart';

class StudentInstantDataScreen extends StatefulWidget {
  final String sessionId;

  const StudentInstantDataScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _StudentInstantDataScreenState createState() => _StudentInstantDataScreenState();
}

class _StudentInstantDataScreenState extends State<StudentInstantDataScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Map<String, dynamic> _fieldValues = {};
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? sessionData;
  List<Map<String, dynamic>> customFields = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isSessionEnded = false;
  bool submissionSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _loadSession() async {
    print('📊 Opening instant data collection: ${widget.sessionId}');

    try {
      final sessionSnapshot = await _dbRef.child('instant_data_collection/${widget.sessionId}').get();
      
      if (!sessionSnapshot.exists) {
        print('⚠️ Session not found!');
        setState(() => isLoading = false);
        _showErrorDialog('Session not found or has been deleted.');
        return;
      }
      
      Map<String, dynamic> data = Map<String, dynamic>.from(sessionSnapshot.value as Map);
      bool sessionEnded = data['status'] == 'ended';
      
      // Parse custom fields
      if (data.containsKey('custom_fields')) {
        customFields = List<Map<String, dynamic>>.from(
          (data['custom_fields'] as List).map((f) => Map<String, dynamic>.from(f))
        );
      }
      
      setState(() {
        sessionData = data;
        isSessionEnded = sessionEnded;
        isLoading = false;
      });

      print('✅ Session loaded: ${data['title']}');
      print('   Custom fields: ${customFields.length}');
      print('   Session ended: $sessionEnded');
    } catch (e) {
      print('❌ Error loading session: $e');
      setState(() => isLoading = false);
      _showErrorDialog('Error loading session. Please check your connection.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Error', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitResponse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate custom fields
    print('🔍 Validating custom fields...');
    for (var field in customFields) {
      String fieldName = field['name'];
      bool isRequired = field['required'] ?? false;
      
      if (isRequired) {
        dynamic value = _fieldValues[fieldName];
        
        if (value == null || value.toString().trim().isEmpty) {
          EnhancedSnackBar.show(
            context,
            message: 'Please fill in $fieldName',
            type: SnackBarType.error,
          );
          return;
        }
      }
    }

    setState(() => isSubmitting = true);

    print('✍️ Submitting response...');
    print('   Session: ${widget.sessionId}');

    try {
      // Get device fingerprint
      String deviceId = await DeviceFingerprintService.getFingerprint();
      print('   Device ID: ${deviceId.substring(0, 20)}...');

      // Submit response
      DatabaseReference responseRef = _dbRef
          .child('instant_data_collection/${widget.sessionId}/responses')
          .push();

      Map<String, dynamic> responseData = {
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        'field_values': _fieldValues,
      };

      await responseRef.set(responseData);

      print('✅ Response submitted successfully!');
      
      setState(() {
        isSubmitting = false;
        submissionSuccess = true;
      });

      // Show success message
      EnhancedSnackBar.show(
        context,
        message: 'Response submitted successfully! ✓',
        type: SnackBarType.success,
      );
    } catch (e, stackTrace) {
      print('❌ Error submitting response: $e');
      print('Stack trace: $stackTrace');
      setState(() => isSubmitting = false);

      EnhancedSnackBar.show(
        context,
        message: 'Error submitting response. Please try again.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'lib/assets/animations/runningcuteanimation.json',
                width: 300,
                height: 300,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      );
    }

    if (sessionData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: ErrorStateWidget(
          title: 'Session Not Found',
          message: 'This session doesn\'t exist or has been deleted.',
          icon: Icons.error_outline_rounded,
          onRetry: () => Navigator.pop(context),
        ),
      );
    }

    // Check if session has ended
    if (isSessionEnded) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Session Ended', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          automaticallyImplyLeading: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_rounded,
                  size: 80,
                  color: ThemeHelper.getErrorColor(context),
                ),
                const SizedBox(height: 24),
                Text(
                  'Session Ended',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This data collection session has been closed. You can no longer submit responses.',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Success screen
    if (submissionSuccess) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SuccessAnimation(
                  size: 120,
                  color: const Color(0xfff59e0b),
                ),
                const SizedBox(height: 32),
                FadeInWidget(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'Response Submitted!',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FadeInWidget(
                  delay: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xfff59e0b).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: const Color(0xfff59e0b),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Thank you for submitting your response!',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: ThemeHelper.getTextPrimary(context),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your data has been recorded successfully.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInWidget(
                  delay: const Duration(milliseconds: 800),
                  child: Text(
                    sessionData!['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextTertiary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main form screen
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Data Collection', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session Header Card
                    SlideInWidget(
                      delay: const Duration(milliseconds: 100),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xfff59e0b), Color(0xfffbbf24)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xfff59e0b).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                    sessionData!['title'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sessionData!['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sessionData!['description'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.white.withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Fields Header
                    FadeInWidget(
                      delay: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_note_rounded,
                              color: const Color(0xfff59e0b),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Please fill in the details',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Render Custom Fields
                    ...customFields.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> field = entry.value;
                      
                      return SlideInWidget(
                        delay: Duration(milliseconds: 300 + (index * 80)),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: CustomFieldWidget(
                            fieldConfig: field,
                            onValueChanged: (String fieldName, dynamic value) {
                              setState(() {
                                _fieldValues[fieldName] = value;
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 12),

                    // Submit Button
                    FadeInWidget(
                      delay: Duration(milliseconds: 400 + (customFields.length * 80)),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submitResponse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff59e0b),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            disabledBackgroundColor: const Color(0xfff59e0b).withValues(alpha: 0.5),
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Submit Response',
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

                    const SizedBox(height: 20),

                    // Helper text
                    FadeInWidget(
                      delay: Duration(milliseconds: 500 + (customFields.length * 80)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: const Color(0xfff59e0b),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your response will be recorded securely. Please ensure all required fields are filled correctly.',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                  height: 1.5,
                                ),
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
          ],
        ),
      ),
    );
  }
}
