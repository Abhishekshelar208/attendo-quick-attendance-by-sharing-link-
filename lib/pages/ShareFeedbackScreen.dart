import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';

class ShareFeedbackScreen extends StatefulWidget {
  final String sessionId;

  const ShareFeedbackScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _ShareFeedbackScreenState createState() => _ShareFeedbackScreenState();
}

class _ShareFeedbackScreenState extends State<ShareFeedbackScreen> with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? sessionData;
  List<Map<String, dynamic>> submissions = [];
  List<Map<String, dynamic>> flaggedSubmissions = [];
  bool isLoading = true;
  bool sessionEnded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchSessionDetails();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fetchSessionDetails() async {
    print('📚 Fetching feedback session details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('feedback_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        setState(() {
          sessionData = Map<String, dynamic>.from(snapshot.value as Map);
          sessionEnded = sessionData!['status'] == 'ended';
          isLoading = false;
        });
        print('✅ Session loaded: ${sessionData!['title']}');
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

    _dbRef.child('feedback_sessions/${widget.sessionId}/submissions').onValue.listen((event) {
      if (event.snapshot.exists) {
        print('🔄 Submissions update received');

        List<Map<String, dynamic>> loadedSubmissions = [];
        List<Map<String, dynamic>> loadedFlagged = [];
        Map<dynamic, dynamic> submissionsMap = event.snapshot.value as Map<dynamic, dynamic>;

        submissionsMap.forEach((key, value) {
          Map<String, dynamic> submission = Map<String, dynamic>.from(value as Map);
          submission['id'] = key;
          
          if (submission['flagged'] == true) {
            loadedFlagged.add(submission);
          } else {
            loadedSubmissions.add(submission);
          }
        });

        // Sort by timestamp
        loadedSubmissions.sort((a, b) {
          DateTime timeA = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
          DateTime timeB = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
          return timeB.compareTo(timeA);
        });

        loadedFlagged.sort((a, b) {
          DateTime timeA = DateTime.parse(a['timestamp'] ?? DateTime.now().toIso8601String());
          DateTime timeB = DateTime.parse(b['timestamp'] ?? DateTime.now().toIso8601String());
          return timeB.compareTo(timeA);
        });

        setState(() {
          submissions = loadedSubmissions;
          flaggedSubmissions = loadedFlagged;
        });

        print('   Total submissions: ${submissions.length}');
        print('   Flagged submissions: ${flaggedSubmissions.length}');
      } else {
        setState(() {
          submissions = [];
          flaggedSubmissions = [];
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
      duration: Duration(seconds: 2),
    );
  }

  void _shareLink() {
    String sessionType = sessionData!['session_type'];
    Share.share(
      'Join $sessionType session: ${sessionData!['title']}\\n'
      '${sessionData!['description'].isNotEmpty ? sessionData!['description'] + '\\n\\n' : ''}'
      'Submit here: $shareUrl',
      subject: '$sessionType Session - ${sessionData!['title']}',
    );
  }

  void _endSession() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Session?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will close the session. Students can no longer submit responses after this.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef.child('feedback_sessions/${widget.sessionId}/status').set('ended');
        setState(() => sessionEnded = true);

        EnhancedSnackBar.show(
          context,
          message: 'Session ended successfully ✓',
          type: SnackBarType.success,
        );
      } catch (e) {
        print('❌ Error ending session: $e');
      }
    }
  }

  Future<void> _flagSubmission(Map<String, dynamic> submission) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flag_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Flag as Abuse?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'This will move the submission to the "Flagged" tab and reveal device information.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Flag'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef
            .child('feedback_sessions/${widget.sessionId}/submissions/${submission['id']}/flagged')
            .set(true);
        
        EnhancedSnackBar.show(
          context,
          message: 'Submission flagged successfully ⚠️',
          type: SnackBarType.warning,
        );
      } catch (e) {
        print('❌ Error flagging submission: $e');
      }
    }
  }

  Future<void> _unflagSubmission(Map<String, dynamic> submission) async {
    try {
      await _dbRef
          .child('feedback_sessions/${widget.sessionId}/submissions/${submission['id']}/flagged')
          .set(false);
      
      EnhancedSnackBar.show(
        context,
        message: 'Submission unflagged ✓',
        type: SnackBarType.success,
      );
    } catch (e) {
      print('❌ Error unflagging submission: $e');
    }
  }

  Future<void> _blockDevice(String deviceId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Block Device?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'This device will no longer be able to submit responses in this session.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef
            .child('feedback_sessions/${widget.sessionId}/blocked_devices/$deviceId')
            .set(true);
        
        EnhancedSnackBar.show(
          context,
          message: 'Device blocked successfully 🚫',
          type: SnackBarType.error,
        );
      } catch (e) {
        print('❌ Error blocking device: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
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

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          sessionData!['title'],
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!sessionEnded)
            IconButton(
              icon: Icon(Icons.stop_circle_rounded),
              onPressed: _endSession,
              tooltip: 'End Session',
            ),
        ],
      ),
      body: Column(
        children: [
          // Session Info Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: ThemeHelper.getPrimaryGradient(context),
              borderRadius: BorderRadius.circular(16),
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
                Row(
                  children: [
                    Icon(
                      sessionData!['session_type'] == 'Feedback'
                          ? Icons.rate_review_rounded
                          : Icons.question_answer_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sessionData!['session_type'],
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${sessionData!['year']} • ${sessionData!['branch']} • ${sessionData!['division']}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sessionEnded
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sessionEnded ? 'Ended' : 'Active',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sessionData!['description'].isNotEmpty) ...[
                  SizedBox(height: 12),
                  Text(
                    sessionData!['description'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ],
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        '${submissions.length + flaggedSubmissions.length}',
                        Icons.list_alt_rounded,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Flagged',
                        '${flaggedSubmissions.length}',
                        Icons.flag_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Share Options
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: Icon(Icons.link_rounded),
                    label: Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: ThemeHelper.getPrimaryColor(context)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareLink,
                    icon: Icon(Icons.share_rounded),
                    label: Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  onPressed: _showQRCode,
                  icon: Icon(Icons.qr_code_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: ThemeHelper.getPrimaryColor(context),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: ThemeHelper.getPrimaryColor(context),
            unselectedLabelColor: ThemeHelper.getTextSecondary(context),
            indicatorColor: ThemeHelper.getPrimaryColor(context),
            tabs: [
              Tab(text: 'Submissions (${submissions.length})'),
              Tab(text: 'Flagged (${flaggedSubmissions.length})'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubmissionsList(submissions, isFlagged: false),
                _buildSubmissionsList(flaggedSubmissions, isFlagged: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList(List<Map<String, dynamic>> items, {required bool isFlagged}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFlagged ? Icons.check_circle_rounded : Icons.inbox_rounded,
              size: 64,
              color: ThemeHelper.getTextTertiary(context),
            ),
            SizedBox(height: 16),
            Text(
              isFlagged ? 'No flagged submissions' : 'No submissions yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: ThemeHelper.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final submission = items[index];
        final DateTime timestamp = DateTime.parse(submission['timestamp']);
        final bool isAnonymous = !sessionData!['collect_names'];
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: ThemeHelper.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: isFlagged
                ? Border.all(color: Colors.orange, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: ThemeHelper.getShadowColor(context),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFlagged
                      ? Colors.orange.withValues(alpha: 0.1)
                      : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAnonymous ? Icons.person_off_rounded : Icons.person_rounded,
                      size: 18,
                      color: isFlagged ? Colors.orange : ThemeHelper.getPrimaryColor(context),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAnonymous
                            ? 'Anonymous #${index + 1}'
                            : submission['student_name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: ThemeHelper.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  submission['content'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
              ),

              // Device Info (for flagged or when revealing)
              if (isFlagged && submission['device_id'] != null) ...[
                Divider(height: 1),
                Container(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.phone_android_rounded, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Device: ...${submission['device_id'].toString().substring(submission['device_id'].toString().length - 8)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Actions
              Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isFlagged)
                      TextButton.icon(
                        onPressed: () => _flagSubmission(submission),
                        icon: Icon(Icons.flag_rounded, size: 18),
                        label: Text('Flag'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    if (isFlagged) ...[
                      TextButton.icon(
                        onPressed: () => _unflagSubmission(submission),
                        icon: Icon(Icons.check_rounded, size: 18),
                        label: Text('Unflag'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                      SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _blockDevice(submission['device_id']),
                        icon: Icon(Icons.block_rounded, size: 18),
                        label: Text('Block Device'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: shareUrl,
                version: QrVersions.auto,
                size: 250,
              ),
            ),
            SizedBox(height: 16),
            Text(
              sessionData!['title'],
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
