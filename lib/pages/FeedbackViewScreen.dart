import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';

class FeedbackViewScreen extends StatefulWidget {
  final String sessionId;

  const FeedbackViewScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _FeedbackViewScreenState createState() => _FeedbackViewScreenState();
}

class _FeedbackViewScreenState extends State<FeedbackViewScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? sessionData;
  List<Map<String, dynamic>> responses = [];
  List<Map<String, dynamic>> customFields = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSessionData();
    _setupRealtimeListener();
  }

  void _fetchSessionData() async {
    print('📚 Fetching session data for: ${widget.sessionId}');

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

        setState(() {
          sessionData = data;
          isLoading = false;
        });
        
        print('✅ Session loaded: ${data['name']} (${data['type']})');
        print('   Custom fields: ${customFields.length}');
      } else {
        print('⚠️ Session not found!');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading session: $e');
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    print('🔊 Setting up real-time listener for responses');

    _dbRef.child('feedback_sessions/${widget.sessionId}/responses').onValue.listen((event) {
      if (event.snapshot.exists) {
        print('🔄 Responses update received');

        List<Map<String, dynamic>> loadedResponses = [];
        Map<dynamic, dynamic> responsesMap = event.snapshot.value as Map<dynamic, dynamic>;

        responsesMap.forEach((key, value) {
          Map<String, dynamic> response = Map<String, dynamic>.from(value as Map);
          response['id'] = key;
          loadedResponses.add(response);
        });

        // Sort by timestamp (newest first)
        loadedResponses.sort((a, b) {
          String timestampA = a['timestamp'] ?? '';
          String timestampB = b['timestamp'] ?? '';
          return timestampB.compareTo(timestampA);
        });

        setState(() {
          responses = loadedResponses;
        });

        print('   Total responses: ${responses.length}');
      } else {
        setState(() => responses = []);
      }
    });
  }

  IconData _getFieldIcon(String type) {
    switch (type) {
      case 'number':
        return Icons.numbers_rounded;
      case 'email':
        return Icons.email_rounded;
      case 'phone':
        return Icons.phone_rounded;
      case 'dropdown':
        return Icons.arrow_drop_down_circle_rounded;
      case 'radio':
        return Icons.radio_button_checked_rounded;
      case 'checkbox':
        return Icons.check_box_rounded;
      case 'yesno':
        return Icons.toggle_on_rounded;
      case 'rating':
        return Icons.star_rounded;
      case 'textarea':
        return Icons.notes_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      DateTime now = DateTime.now();
      Duration diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}h ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildResponseValue(dynamic value, String fieldType) {
    if (value == null) {
      return Text(
        'Not answered',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: ThemeHelper.getTextTertiary(context),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Handle rating specially
    if (fieldType == 'rating') {
      int rating = int.tryParse(value.toString()) ?? 0;
      return Row(
        children: List.generate(5, (index) {
          return Icon(
            index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: Colors.amber,
            size: 20,
          );
        }),
      );
    }

    // Handle checkboxes (list of values)
    if (value is List) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: value.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.toString(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.getPrimaryColor(context),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Handle yes/no
    if (fieldType == 'yesno') {
      bool isYes = value.toString().toLowerCase() == 'yes' || value.toString().toLowerCase() == 'true';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isYes ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isYes ? 'Yes' : 'No',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isYes ? Colors.green : Colors.red,
          ),
        ),
      );
    }

    // Regular text
    return Text(
      value.toString(),
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: ThemeHelper.getTextPrimary(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Responses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: LoadingIndicator(message: 'Loading responses...'),
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

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Responses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sessionType == 'Q&A' 
                      ? [const Color(0xff3b82f6), const Color(0xff60a5fa)]
                      : [const Color(0xff059669), const Color(0xff10b981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.3),
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
                        sessionType == 'Q&A' ? Icons.question_answer_rounded : Icons.rate_review_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sessionData!['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${responses.length} ${responses.length == 1 ? 'Response' : 'Responses'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Responses List
            Expanded(
              child: responses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 80,
                            color: ThemeHelper.getTextTertiary(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No responses yet',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Responses will appear here once students submit',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ThemeHelper.getTextTertiary(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: responses.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> response = responses[index];
                        Map<String, dynamic>? fieldValues = response.containsKey('field_values')
                            ? Map<String, dynamic>.from(response['field_values'] as Map)
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: ThemeHelper.getCardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ThemeHelper.getBorderColor(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                'Response #${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                              subtitle: Text(
                                _formatTimestamp(response['timestamp'] ?? ''),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                              children: [
                                if (customFields.isEmpty && fieldValues == null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'No fields configured for this session',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: ThemeHelper.getTextTertiary(context),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else if (fieldValues != null)
                                  ...customFields.map((field) {
                                    String fieldName = field['name'];
                                    String fieldType = field['type'] ?? 'text';
                                    dynamic fieldValue = fieldValues[fieldName];

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: typeColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              _getFieldIcon(fieldType),
                                              color: typeColor,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fieldName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: ThemeHelper.getTextSecondary(context),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                _buildResponseValue(fieldValue, fieldType),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
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
