import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'FeedbackViewScreen.dart';

class ShareFeedbackScreen extends StatefulWidget {
  final String sessionId;

  const ShareFeedbackScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _ShareFeedbackScreenState createState() => _ShareFeedbackScreenState();
}

class _ShareFeedbackScreenState extends State<ShareFeedbackScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? sessionData;
  int responseCount = 0;
  bool isLoading = true;
  bool sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
    _setupRealtimeListener();
  }

  void _fetchSessionDetails() async {
    print('📚 Fetching session details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        setState(() {
          sessionData = Map<String, dynamic>.from(snapshot.value as Map);
          sessionEnded = sessionData!['status'] == 'ended';
          isLoading = false;
        });
        print('✅ Session loaded: ${sessionData!['name']} (${sessionData!['type']})');
      } else {
        print('⚠️ Session not found!');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching session: $e');
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    print('🔊 Setting up real-time listener for session: ${widget.sessionId}');

    _dbRef.child('feedback_sessions/${widget.sessionId}/responses').onValue.listen((event) {
      if (event.snapshot.exists) {
        print('🔄 Responses update received');
        Map<dynamic, dynamic> responsesMap = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          responseCount = responsesMap.length;
        });
        print('   Current responses: $responseCount');
      } else {
        setState(() => responseCount = 0);
      }
    });

    // Listen for status changes
    _dbRef.child('feedback_sessions/${widget.sessionId}/status').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          sessionEnded = event.snapshot.value == 'ended';
        });
      }
    });
  }

  String get shareUrl => 'https://attendo-312ea.web.app/#/feedback/${widget.sessionId}';

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: shareUrl));
    EnhancedSnackBar.show(
      context,
      message: 'Link copied to clipboard! 📋',
      type: SnackBarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  void _shareLink() {
    String type = sessionData!['type'];
    String emoji = type == 'Q&A' ? '💬' : '📝';
    
    final text = '''
$emoji ${sessionData!['name']}

${type} Session - Share your valuable feedback!

📅 Created: ${_formatTimestamp(sessionData!['created_at'])}
👥 Status: ${sessionEnded ? 'Ended' : 'Active'}
📊 Responses: $responseCount

Submit your response:
$shareUrl
''';
    Share.share(text, subject: '$type Session - ${sessionData!['name']}');
  }
  
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime dt = DateTime.parse(timestamp);
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  void _endSession() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('End Session?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will close the session. Students will no longer be able to submit responses after this.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeHelper.getErrorColor(context),
            ),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef.child('feedback_sessions/${widget.sessionId}').update({
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        });

        setState(() => sessionEnded = true);

        EnhancedSnackBar.show(
          context,
          message: 'Session ended successfully ✓',
          type: SnackBarType.success,
        );
      } catch (e) {
        print('❌ Error ending session: $e');
        EnhancedSnackBar.show(
          context,
          message: 'Error ending session',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _viewResponses() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackViewScreen(sessionId: widget.sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: LoadingIndicator(message: 'Loading session details...'),
      );
    }

    if (sessionData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Session Not Found', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: ErrorStateWidget(
          title: 'Session Not Found',
          message: 'This session doesn\'t exist or has been deleted.',
          icon: Icons.error_outline_rounded,
          onRetry: () => Navigator.pop(context),
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
        actions: [
          if (!sessionEnded)
            IconButton(
              icon: const Icon(Icons.stop_circle_rounded),
              onPressed: _endSession,
              tooltip: 'End Session',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session Status Banner
              if (sessionEnded)
                SlideInWidget(
                  delay: const Duration(milliseconds: 100),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getErrorColor(context).withValues(alpha: 0.1),
                      border: Border.all(color: ThemeHelper.getErrorColor(context)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded, color: ThemeHelper.getErrorColor(context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This session has ended. No new responses allowed.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: ThemeHelper.getErrorColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Session Details Card
              SlideInWidget(
                delay: const Duration(milliseconds: 200),
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
                            child: Icon(typeIcon, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sessionData!['name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$sessionType Session',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.people_rounded, '$responseCount', 'Responses'),
                            Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                            _buildStatItem(
                              sessionEnded ? Icons.stop_circle_rounded : Icons.play_circle_rounded,
                              sessionEnded ? 'Ended' : 'Active',
                              'Status',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // QR Code Section
              if (!sessionEnded) ...[
                SlideInWidget(
                  delay: const Duration(milliseconds: 300),
                  child: Text(
                    'QR Code for Quick Access',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInWidget(
                  delay: const Duration(milliseconds: 400),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: shareUrl,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Share Buttons
                SlideInWidget(
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.content_copy_rounded),
                          label: const Text('Copy Link'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareLink,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // View Responses Button
              SlideInWidget(
                delay: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _viewResponses,
                    icon: const Icon(Icons.visibility_rounded, size: 24),
                    label: Text(
                      'View Responses ($responseCount)',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Session Button
              if (!sessionEnded)
                SlideInWidget(
                  delay: const Duration(milliseconds: 700),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _endSession,
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: Text(
                        'End Session',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeHelper.getErrorColor(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: ThemeHelper.getErrorColor(context), width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
