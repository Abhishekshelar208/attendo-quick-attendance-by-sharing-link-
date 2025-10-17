import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'InstantDataViewScreen.dart';

class ShareInstantDataScreen extends StatefulWidget {
  final String sessionId;

  const ShareInstantDataScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _ShareInstantDataScreenState createState() => _ShareInstantDataScreenState();
}

class _ShareInstantDataScreenState extends State<ShareInstantDataScreen> {
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
      final snapshot = await _dbRef.child('instant_data_collection/${widget.sessionId}').get();

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

    _dbRef.child('instant_data_collection/${widget.sessionId}/responses').onValue.listen((event) {
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
    _dbRef.child('instant_data_collection/${widget.sessionId}/status').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          sessionEnded = event.snapshot.value == 'ended';
        });
      }
    });
  }

  String get shareUrl => 'https://attendo-312ea.web.app/#/instant-data/${widget.sessionId}';

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
    final text = '''
📊 ${sessionData!['title']}

${sessionData!['description'].isNotEmpty ? sessionData!['description'] + '\n\n' : ''}📅 Created: ${_formatTimestamp(sessionData!['created_at'])}
👥 Status: ${sessionEnded ? 'Ended' : 'Active'}
📝 Responses: $responseCount

Submit your response:
$shareUrl
''';
    Share.share(text, subject: 'Data Collection - ${sessionData!['title']}');
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
        title: Text('End Data Collection?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
        await _dbRef.child('instant_data_collection/${widget.sessionId}').update({
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
          title: Text('Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: ErrorStateWidget(
          title: 'Session Not Found',
          message: 'This session doesn\'t exist or has been deleted.',
          icon: Icons.error_outline_rounded,
          onRetry: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Share Data Collection',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!sessionEnded)
            IconButton(
              icon: Icon(Icons.stop_circle_outlined),
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
              // Status Banner
              if (sessionEnded)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getErrorColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThemeHelper.getErrorColor(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: ThemeHelper.getErrorColor(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Session Ended - No new responses accepted',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.getErrorColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: ThemeHelper.getSuccessColor(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Session Active - Accepting responses',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.getSuccessColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Session Info Card
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
                          child: Text(
                            sessionData!['description'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(sessionData!['created_at']),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Response Count Card
              SlideInWidget(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeHelper.getBorderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.getShadowColor(context),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.people_rounded,
                          color: const Color(0xfff59e0b),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Responses',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$responseCount',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xfff59e0b),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Share Section
              Text(
                'Share with Students',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),

              // Link Display
              SlideInWidget(
                delay: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeHelper.getBorderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: ThemeHelper.getTextSecondary(context),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shareUrl,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SlideInWidget(
                      delay: const Duration(milliseconds: 400),
                      begin: const Offset(-0.2, 0),
                      child: ElevatedButton.icon(
                        onPressed: _copyLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getPrimaryColor(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.content_copy_rounded, size: 20),
                        label: Text(
                          'Copy Link',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SlideInWidget(
                      delay: const Duration(milliseconds: 500),
                      begin: const Offset(0.2, 0),
                      child: ElevatedButton.icon(
                        onPressed: _shareLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xfff59e0b),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          'Share',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // QR Code Display
              SlideInWidget(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeHelper.getBorderColor(context)),
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
                      Text(
                        'Scan QR Code',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: shareUrl,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Students can scan this QR code to submit their response',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Instructions
              FadeInWidget(
                delay: const Duration(milliseconds: 700),
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
                        Icons.lightbulb_outline_rounded,
                        color: const Color(0xfff59e0b),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Share the link or QR code with students. They can submit their responses directly without installing any app.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: ThemeHelper.getTextSecondary(context),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // View Responses Button
              SlideInWidget(
                delay: const Duration(milliseconds: 700),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstantDataViewScreen(sessionId: widget.sessionId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 24),
                    label: Text(
                      'View Responses ($responseCount)',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff59e0b),
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
