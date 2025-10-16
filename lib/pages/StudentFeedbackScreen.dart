import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'FeedbackViewScreen.dart';
import 'package:lottie/lottie.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final String sessionId;

  const StudentFeedbackScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _StudentFeedbackScreenState createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  Map<String, dynamic>? sessionData;
  bool isLoading = true;
  bool isSubmitting = false;
  String? alreadySubmittedContent;
  int characterLimit = 500;
  bool sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndLoadSession();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _checkDeviceAndLoadSession() async {
    print('📱 Opening feedback session: ${widget.sessionId}');

    String deviceId = await DeviceFingerprintService.getFingerprint();
    print('🔐 Device ID: ${deviceId.substring(0, 20)}...');

    await _checkIfDeviceSubmitted(deviceId);
  }

  Future<void> _checkIfDeviceSubmitted(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    String storageKey = 'feedback_${widget.sessionId}';
    
    // Check localStorage first
    String? localSubmission = prefs.getString(storageKey);
    if (localSubmission != null) {
      print('💾 Found local submission');
      
      // Verify in Firebase
      final snapshot = await _dbRef
          .child('feedback_sessions/${widget.sessionId}/submissions')
          .get();

      bool found = false;
      String? foundContent;
      
      if (snapshot.exists) {
        final submissionsMap = snapshot.value as Map;
        for (var submission in submissionsMap.values) {
          if (submission['device_id'] == deviceId) {
            found = true;
            foundContent = submission['content'];
            break;
          }
        }
      }

      if (found) {
        print('✅ Device already submitted (verified in Firebase)');
        
        // Check if multiple submissions allowed
        _fetchSessionDetails();
        
        if (sessionData != null && sessionData!['allow_multiple_submissions'] == false) {
          setState(() {
            alreadySubmittedContent = foundContent;
            isLoading = false;
          });

          await Future.delayed(Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => FeedbackViewScreen(
                  sessionId: widget.sessionId,
                  hasSubmitted: true,
                ),
              ),
            );
          }
          return;
        }
      }
    }

    // Load session details
    _fetchSessionDetails();
  }

  void _fetchSessionDetails() async {
    print('📚 Fetching session details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        
        setState(() {
          sessionData = data;
          sessionEnded = data['status'] == 'ended';
          characterLimit = data['character_limit'] ?? 500;
          isLoading = false;
        });

        print('✅ Session loaded: ${data['title']}');
        print('   Type: ${data['session_type']}');
        print('   Collect names: ${data['collect_names']}');
        print('   Allow multiple: ${data['allow_multiple_submissions']}');
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
        title: Text('Error', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _submitFeedback() async {
    if (sessionEnded) {
      EnhancedSnackBar.show(
        context,
        message: 'Session has ended',
        type: SnackBarType.error,
      );
      return;
    }

    bool collectNames = sessionData!['collect_names'] ?? true;
    String content = _contentController.text.trim();
    String? studentName = collectNames ? _nameController.text.trim() : null;

    // Validation
    if (collectNames && (studentName == null || studentName.isEmpty)) {
      EnhancedSnackBar.show(
        context,
        message: 'Please enter your name',
        type: SnackBarType.error,
      );
      return;
    }

    if (content.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'Please enter your ${sessionData!['session_type'].toLowerCase()}',
        type: SnackBarType.error,
      );
      return;
    }

    if (sessionData!.containsKey('character_limit') && content.length > sessionData!['character_limit']) {
      EnhancedSnackBar.show(
        context,
        message: 'Content exceeds character limit (${sessionData!['character_limit']})',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => isSubmitting = true);

    print('✍️ Submitting ${sessionData!['session_type']}...');
    print('   Session: ${widget.sessionId}');
    if (collectNames) print('   Name: $studentName');
    print('   Content length: ${content.length}');

    try {
      String deviceId = await DeviceFingerprintService.getFingerprint();
      print('   Device ID: ${deviceId.substring(0, 20)}...');

      // Check if device is blocked
      final blockedSnapshot = await _dbRef
          .child('feedback_sessions/${widget.sessionId}/blocked_devices/$deviceId')
          .get();

      if (blockedSnapshot.exists && blockedSnapshot.value == true) {
        setState(() => isSubmitting = false);
        
        EnhancedSnackBar.show(
          context,
          message: 'Your device has been blocked from this session',
          type: SnackBarType.error,
        );
        return;
      }

      // Check if already submitted (if multiple submissions not allowed)
      if (sessionData!['allow_multiple_submissions'] == false) {
        final allSubmissionsSnapshot = await _dbRef
            .child('feedback_sessions/${widget.sessionId}/submissions')
            .get();
        
        if (allSubmissionsSnapshot.exists) {
          final submissionsMap = allSubmissionsSnapshot.value as Map;
          for (var submission in submissionsMap.values) {
            if (submission['device_id'] == deviceId) {
              setState(() => isSubmitting = false);
              
              EnhancedSnackBar.show(
                context,
                message: 'You have already submitted',
                type: SnackBarType.warning,
              );

              await Future.delayed(Duration(seconds: 1));
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FeedbackViewScreen(
                      sessionId: widget.sessionId,
                      hasSubmitted: true,
                    ),
                  ),
                );
              }
              return;
            }
          }
        }
      }

      // Submit
      DatabaseReference submissionRef = _dbRef
          .child('feedback_sessions/${widget.sessionId}/submissions')
          .push();

      Map<String, dynamic> submissionData = {
        'content': content,
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
        'flagged': false,
      };

      if (collectNames) {
        submissionData['student_name'] = studentName;
      }

      await submissionRef.set(submissionData);

      // Store in localStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('feedback_${widget.sessionId}', content);

      print('✅ Submission successful!');

      setState(() => isSubmitting = false);

      // Navigate to view screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackViewScreen(
            sessionId: widget.sessionId,
            hasSubmitted: true,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error submitting: $e');
      setState(() => isSubmitting = false);
      
      EnhancedSnackBar.show(
        context,
        message: 'Error submitting. Please try again.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Lottie.asset(
            'lib/assets/animations/runningcuteanimation.json',
            width: 300,
            height: 300,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    if (sessionData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(title: Text('Error')),
        body: Center(
          child: Text(
            'Session not found',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
        ),
      );
    }

    if (sessionEnded) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            sessionData!['title'],
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade700],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 32),
                Text(
                  'Session Ended',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'This session has been closed by the teacher',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    bool collectNames = sessionData!['collect_names'] ?? true;
    String sessionType = sessionData!['session_type'];

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          sessionData!['title'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.getPrimaryGradient(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    sessionType == 'Feedback'
                        ? Icons.rate_review_rounded
                        : Icons.question_answer_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Session Info Card
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ThemeHelper.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      sessionData!['title'],
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (sessionData!['description'].isNotEmpty) ...[
                      SizedBox(height: 12),
                      Text(
                        sessionData!['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${sessionData!['year']} • ${sessionData!['branch']} • ${sessionData!['division']}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Input Card
              Container(
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeHelper.getShadowColor(context),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: ThemeHelper.getPrimaryColor(context),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Your $sessionType',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      collectNames
                          ? 'Enter your name and $sessionType below'
                          : 'Submit anonymously',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                    SizedBox(height: 28),

                    // Name Field (if required)
                    if (collectNames) ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Your Name *',
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: ThemeHelper.getPrimaryColor(context),
                          ),
                          filled: true,
                          fillColor: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: ThemeHelper.getBorderColor(context),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: ThemeHelper.getPrimaryColor(context),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // Content Field
                    TextField(
                      controller: _contentController,
                      maxLines: 6,
                      maxLength: characterLimit,
                      decoration: InputDecoration(
                        labelText: '$sessionType *',
                        hintText: sessionType == 'Feedback'
                            ? 'Share your thoughts...'
                            : 'Ask your question...',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 80),
                          child: Icon(
                            sessionType == 'Feedback'
                                ? Icons.message_rounded
                                : Icons.help_rounded,
                            color: ThemeHelper.getPrimaryColor(context),
                          ),
                        ),
                        filled: true,
                        fillColor: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: ThemeHelper.getBorderColor(context),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: ThemeHelper.getPrimaryColor(context),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    if (!collectNames) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: ThemeHelper.getWarningColor(context),
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your submission is anonymous, but device tracking is enabled for safety',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
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

              SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.getPrimaryColor(context),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: isSubmitting
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Submit $sessionType',
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
    );
  }
}
