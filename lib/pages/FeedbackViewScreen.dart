import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';

class FeedbackViewScreen extends StatefulWidget {
  final String sessionId;
  final bool hasSubmitted;

  const FeedbackViewScreen({
    Key? key,
    required this.sessionId,
    this.hasSubmitted = false,
  }) : super(key: key);

  @override
  _FeedbackViewScreenState createState() => _FeedbackViewScreenState();
}

class _FeedbackViewScreenState extends State<FeedbackViewScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? sessionData;
  int totalSubmissions = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessionData();
    _listenForSubmissions();
  }

  void _fetchSessionData() async {
    try {
      final snapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        setState(() {
          sessionData = Map<String, dynamic>.from(snapshot.value as Map);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching session data: $e');
      setState(() => isLoading = false);
    }
  }

  void _listenForSubmissions() {
    _dbRef.child('feedback_sessions/${widget.sessionId}/submissions').onValue.listen((event) {
      if (event.snapshot.exists) {
        Map<dynamic, dynamic> submissionsMap = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          totalSubmissions = submissionsMap.length;
        });
      } else {
        setState(() {
          totalSubmissions = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            "QuickPro.",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
        ),
        body: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: ThemeHelper.getPrimaryColor(context),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    
                    // Success Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getSuccessColor(context),
                              ThemeHelper.getSuccessColor(context).withValues(alpha: 0.8),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Success Message Card
                    if (widget.hasSubmitted)
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getSuccessColor(context),
                              ThemeHelper.getSuccessColor(context).withValues(alpha: 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Submitted Successfully!',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Thank you for your ${sessionData?['session_type']?.toLowerCase() ?? 'submission'}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Session Info Card
                    if (sessionData != null)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getCardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeHelper.getShadowColor(context),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  sessionData!['session_type'] == 'Feedback'
                                      ? Icons.rate_review_rounded
                                      : Icons.question_answer_rounded,
                                  color: ThemeHelper.getPrimaryColor(context),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    sessionData!['title'] ?? 'Session',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeHelper.getTextPrimary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sessionData!['description'] != null && 
                                sessionData!['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                sessionData!['description'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (sessionData!['year'] != null && sessionData!['branch'] != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: ThemeHelper.getPrimaryColor(context),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${sessionData!['year']} • ${sessionData!['branch']} • ${sessionData!['division']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Submission Stats Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeHelper.getShadowColor(context),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 48,
                            color: ThemeHelper.getPrimaryColor(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Total Submissions',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$totalSubmissions',
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: ThemeHelper.getPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Device Lock Warning
                    if (widget.hasSubmitted && 
                        sessionData != null && 
                        sessionData!['allow_multiple_submissions'] == false)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              color: ThemeHelper.getPrimaryColor(context),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This device is locked for this session. You cannot submit again.',
                                style: GoogleFonts.poppins(
                                  color: ThemeHelper.getTextPrimary(context),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}
