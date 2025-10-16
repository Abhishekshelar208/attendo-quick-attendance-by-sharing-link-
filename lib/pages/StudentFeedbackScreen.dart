import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/widgets/custom_field_widgets.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:attendo/pages/FeedbackThankYouScreen.dart';
import 'package:attendo/pages/FeedbackSessionEndedScreen.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final String sessionId;

  const StudentFeedbackScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _StudentFeedbackScreenState createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Map<String, dynamic> _fieldValues = {};
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? sessionData;
  List<Map<String, dynamic>> customFields = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool isSessionEnded = false;
  bool alreadySubmitted = false;
  String? submittedTimestamp;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndLoadSession();
  }

  void _checkDeviceAndLoadSession() async {
    print('📱 Opening feedback session: ${widget.sessionId}');

    // Get device fingerprint
    String deviceId = await DeviceFingerprintService.getFingerprint();
    print('🔐 Device ID: ${deviceId.substring(0, 20)}...');

    // Check if device already submitted
    await _checkIfDeviceAlreadySubmitted(deviceId);
  }

  Future<void> _checkIfDeviceAlreadySubmitted(String deviceId) async {
    // First, load session to check if it's ended
    final sessionSnapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();
    
    if (!sessionSnapshot.exists) {
      print('⚠️ Session not found!');
      setState(() => isLoading = false);
      _showErrorDialog('Session not found or has been deleted.');
      return;
    }
    
    Map<String, dynamic> sessionData = Map<String, dynamic>.from(sessionSnapshot.value as Map);
    bool sessionEnded = sessionData['status'] == 'ended';
    
    // If session is ended, show ended screen (regardless of submission status)
    if (sessionEnded) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FeedbackSessionEndedScreen(
              sessionType: sessionData['type'] ?? 'Q&A',
              sessionName: sessionData['name'] ?? 'Session',
            ),
          ),
        );
      }
      return;
    }
    
    // Session is active, always load form (allow unlimited resubmissions)
    _fetchSessionDetails();
  }

  void _fetchSessionDetails() async {
    print('📚 Fetching session details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Parse custom fields if they exist
        if (data.containsKey('custom_fields')) {
          customFields = List<Map<String, dynamic>>.from(
            (data['custom_fields'] as List).map((f) => Map<String, dynamic>.from(f))
          );
        }

        bool sessionEnded = data['status'] == 'ended';
        
        setState(() {
          sessionData = data;
          isSessionEnded = sessionEnded;
          isLoading = false;
        });

        print('✅ Session loaded: ${data['name']} (${data['type']})');
        print('   Custom fields: ${customFields.length}');
        print('   Session ended: $sessionEnded');
      } else {
        print('⚠️ Session not found!');
        setState(() => isLoading = false);
        _showErrorDialog('Session not found or has been deleted.');
      }
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

      // Submit response (allow resubmissions)
      DatabaseReference responseRef = _dbRef
          .child('feedback_sessions/${widget.sessionId}/responses')
          .push();

      Map<String, dynamic> responseData = {
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        'field_values': _fieldValues,
      };

      await responseRef.set(responseData);

      // Save to localStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('feedback_submit_${widget.sessionId}', responseData['timestamp']);

      print('✅ Response submitted successfully!');
      
      setState(() => isSubmitting = false);
      
      // Navigate to thank you screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FeedbackThankYouScreen(
              sessionType: sessionData!['type'] ?? 'Q&A',
              sessionName: sessionData!['name'] ?? 'Session',
            ),
          ),
        );
      }
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
        backgroundColor: alreadySubmitted ? ThemeHelper.getBackgroundColor(context) : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (alreadySubmitted) ...[
                SuccessAnimation(
                  size: 120,
                  color: ThemeHelper.getSuccessColor(context),
                ),
                const SizedBox(height: 24),
                FadeInWidget(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'Already Submitted!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    'You have already submitted your response',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                Lottie.asset(
                  'lib/assets/animations/runningcuteanimation.json',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ],
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
                  'This session has been closed by the teacher. You can no longer submit responses.',
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

    String sessionType = sessionData!['type'] ?? 'Q&A';
    Color typeColor = sessionType == 'Q&A' ? const Color(0xff3b82f6) : const Color(0xff059669);
    IconData typeIcon = sessionType == 'Q&A' ? Icons.question_answer_rounded : Icons.rate_review_rounded;

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('$sessionType Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                          gradient: LinearGradient(
                            colors: sessionType == 'Q&A' 
                                ? [const Color(0xff3b82f6), const Color(0xff60a5fa)]
                                : [const Color(0xff059669), const Color(0xff10b981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: typeColor.withValues(alpha: 0.3),
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
                              child: Icon(typeIcon, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sessionData!['name'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please fill in all the details below',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Custom Fields
                    if (customFields.isEmpty)
                      SlideInWidget(
                        delay: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getCardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ThemeHelper.getBorderColor(context)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 64,
                                  color: ThemeHelper.getTextTertiary(context),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No fields configured',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: ThemeHelper.getTextSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'The teacher hasn\'t added any fields yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: ThemeHelper.getTextTertiary(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...customFields.asMap().entries.map((entry) {
                        int index = entry.key;
                        Map<String, dynamic> field = entry.value;
                        
                        return SlideInWidget(
                          delay: Duration(milliseconds: 300 + (index * 100)),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: CustomFieldWidget(
                              fieldConfig: field,
                              onValueChanged: (fieldName, value) {
                                setState(() {
                                  _fieldValues[fieldName] = value;
                                });
                              },
                            ),
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 32),

                    // Submit Button
                    if (customFields.isNotEmpty)
                      SlideInWidget(
                        delay: Duration(milliseconds: 400 + (customFields.length * 100)),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _submitResponse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Submit Response',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Submitting Overlay
            if (isSubmitting)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Submitting your response...',
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
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
