import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ShareInstantDataCollectionScreen extends StatefulWidget {
  final String sessionId;

  const ShareInstantDataCollectionScreen({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  _ShareInstantDataCollectionScreenState createState() =>
      _ShareInstantDataCollectionScreenState();
}

class _ShareInstantDataCollectionScreenState
    extends State<ShareInstantDataCollectionScreen> {
  Map<String, dynamic>? _sessionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('instant_data_collection')
          .doc(widget.sessionId)
          .get();

      if (doc.exists) {
        setState(() {
          _sessionData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getShareableLink() {
    // Update this with your actual domain/deep link
    return 'https://attendo.app/instant-data/${widget.sessionId}';
  }

  void _copyLinkToClipboard() {
    Clipboard.setData(ClipboardData(text: _getShareableLink()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard!'),
        backgroundColor: ThemeHelper.getSuccessColor(context),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLink() {
    Share.share(
      'Submit your response: ${_getShareableLink()}',
      subject: _sessionData?['title'] ?? 'Data Collection Session',
    );
  }

  Future<void> _toggleSessionStatus() async {
    try {
      final newStatus =
          _sessionData?['status'] == 'active' ? 'closed' : 'active';

      await FirebaseFirestore.instance
          .collection('instant_data_collection')
          .doc(widget.sessionId)
          .update({'status': newStatus});

      setState(() {
        _sessionData?['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'active'
                ? 'Session reopened'
                : 'Session closed',
          ),
          backgroundColor: ThemeHelper.getSuccessColor(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating session status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Scan QR Code',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: ThemeHelper.getTextPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
        content: Container(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _getShareableLink(),
                  version: QrVersions.auto,
                  size: 240,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Students can scan this QR code to access the session',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: ThemeHelper.getPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            'Data Collection',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ThemeHelper.getPrimaryColor(context),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
          ),
        ),
      );
    }

    if (_sessionData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text(
            'Data Collection',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: ThemeHelper.getPrimaryColor(context),
        ),
        body: Center(
          child: Text(
            'Session not found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: ThemeHelper.getTextSecondary(context),
            ),
          ),
        ),
      );
    }

    final isActive = _sessionData!['status'] == 'active';

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          _sessionData!['title'] ?? 'Data Collection',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: ThemeHelper.getPrimaryColor(context),
        actions: [
          IconButton(
            icon: Icon(isActive ? Icons.stop_circle_rounded : Icons.play_circle_rounded),
            onPressed: _toggleSessionStatus,
            tooltip: isActive ? 'Close Session' : 'Reopen Session',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? ThemeHelper.getSuccessColor(context)
                  : Colors.orange,
            ),
            child: Text(
              isActive ? 'Session Active' : 'Session Closed',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Share Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Link Display Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    border: Border.all(
                      color: ThemeHelper.getBorderColor(context),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Link',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeHelper.getBackgroundColor(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getShareableLink(),
                                style: GoogleFonts.robotoMono(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                color: ThemeHelper.getPrimaryColor(context),
                                size: 20,
                              ),
                              onPressed: _copyLinkToClipboard,
                              tooltip: 'Copy Link',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showQRCode,
                        icon: Icon(Icons.qr_code_2_rounded, size: 20),
                        label: Text(
                          'QR Code',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getPrimaryColor(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _shareLink,
                        icon: Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          'Share',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.getSuccessColor(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Submissions Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Submissions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('instant_data_collection')
                      .doc(widget.sessionId)
                      .collection('submissions')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getPrimaryColor(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Submissions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('instant_data_collection')
                  .doc(widget.sessionId)
                  .collection('submissions')
                  .orderBy('submittedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: ThemeHelper.getPrimaryColor(context),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No submissions yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share the link or QR code with students',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.getTextTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final submissions = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final submission =
                        submissions[index].data() as Map<String, dynamic>;
                    final submissionId = submissions[index].id;
                    return _buildSubmissionCard(submission, submissionId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(
    Map<String, dynamic> submission,
    String submissionId,
  ) {
    final studentName = submission['studentName'] ?? 'Anonymous';
    final timestamp = submission['submittedAt'] as Timestamp?;
    final responses = submission['responses'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ThemeHelper.getPrimaryColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person_rounded,
              color: ThemeHelper.getPrimaryColor(context),
              size: 22,
            ),
          ),
          title: Text(
            studentName,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
          subtitle: timestamp != null
              ? Text(
                  _formatTimestamp(timestamp),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                )
              : null,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ThemeHelper.getBackgroundColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (responses.isEmpty)
                    Text(
                      'No responses recorded',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: ThemeHelper.getTextTertiary(context),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    ...responses.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value?.toString() ?? 'No response',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: ThemeHelper.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
