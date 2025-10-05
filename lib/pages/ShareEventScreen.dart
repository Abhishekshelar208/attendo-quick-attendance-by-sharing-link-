import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ShareEventScreen extends StatefulWidget {
  final String sessionId;

  const ShareEventScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _ShareEventScreenState createState() => _ShareEventScreenState();
}

class _ShareEventScreenState extends State<ShareEventScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? eventData;
  List<Map<String, dynamic>> participants = [];
  bool isLoading = true;
  bool eventEnded = false;

  @override
  void initState() {
    super.initState();
    _fetchEventDetails();
    _setupRealtimeListener();
  }

  void _fetchEventDetails() async {
    print('📚 Fetching event details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('event_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        setState(() {
          eventData = Map<String, dynamic>.from(snapshot.value as Map);
          eventEnded = eventData!['status'] == 'ended';
          isLoading = false;
        });
        print('✅ Event loaded: ${eventData!['event_name']}');
      } else {
        print('⚠️ Event not found!');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('❌ Error fetching event: $e');
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    print('🔊 Setting up real-time listener for event: ${widget.sessionId}');

    _dbRef.child('event_sessions/${widget.sessionId}/participants').onValue.listen((event) {
      if (event.snapshot.exists) {
        print('🔄 Participants update received');

        List<Map<String, dynamic>> loadedParticipants = [];
        Map<dynamic, dynamic> participantsMap = event.snapshot.value as Map<dynamic, dynamic>;

        participantsMap.forEach((key, value) {
          Map<String, dynamic> participant = Map<String, dynamic>.from(value as Map);
          participant['id'] = key;
          loadedParticipants.add(participant);
        });

        // Sort participants
        loadedParticipants.sort((a, b) {
          String entryA = a['entry'] ?? '';
          String entryB = b['entry'] ?? '';

          if (int.tryParse(entryA) != null && int.tryParse(entryB) != null) {
            return int.parse(entryA).compareTo(int.parse(entryB));
          }
          return entryA.compareTo(entryB);
        });

        setState(() {
          participants = loadedParticipants;
        });

        print('   Current participants: ${participants.length}');
      } else {
        setState(() => participants = []);
      }
    });
  }

  String get shareUrl => 'https://attendo-312ea.web.app/#/event/${widget.sessionId}';

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
    Share.share(
      'Join event: ${eventData!['event_name']}\n'
      'Venue: ${eventData!['venue']}\n'
      'Date: ${eventData!['date']} at ${eventData!['time']}\n\n'
      'Check-in here: $shareUrl',
      subject: 'Event Check-In - ${eventData!['event_name']}',
    );
  }

  void _endEvent() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Event?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will close check-ins. Participants can no longer join after this.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('End Event'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbRef.child('event_sessions/${widget.sessionId}/status').set('ended');
        setState(() => eventEnded = true);

        EnhancedSnackBar.show(
          context,
          message: 'Event ended successfully ✓',
          type: SnackBarType.success,
        );
      } catch (e) {
        print('❌ Error ending event: $e');
      }
    }
  }

  void _exportAsPDF() async {
    if (eventData == null) return;

    final pdf = pw.Document();
    
    // Check if event has custom fields
    List<Map<String, dynamic>> customFields = [];
    if (eventData!.containsKey('custom_fields')) {
      customFields = List<Map<String, dynamic>>.from(
        (eventData!['custom_fields'] as List).map((f) => Map<String, dynamic>.from(f))
      );
    }
    bool hasCustomFields = customFields.isNotEmpty;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Event Attendance Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Event: ${eventData!['event_name']}', style: pw.TextStyle(fontSize: 16)),
              pw.Text('Venue: ${eventData!['venue']}', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Date: ${eventData!['date']} at ${eventData!['time']}', style: pw.TextStyle(fontSize: 14)),
              pw.Text('Year: ${eventData!['year']} | Branch: ${eventData!['branch']} | Division: ${eventData!['division']}',
                  style: pw.TextStyle(fontSize: 14)),
              if (eventData!.containsKey('capacity'))
                pw.Text('Capacity: ${eventData!['capacity']}', style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Total Participants: ${participants.length}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Participant List:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              // Table header if custom fields exist
              if (hasCustomFields) ...[
                pw.Row(
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    pw.Expanded(flex: 3, child: pw.Text('${eventData!['input_type']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
                    ...customFields.map((field) => pw.Expanded(
                      flex: 2,
                      child: pw.Text(field['name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    )).toList(),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Divider(),
              ],
              // Participant rows
              ...participants.map((p) {
                int index = participants.indexOf(p) + 1;
                if (hasCustomFields) {
                  // Display as table row with custom fields
                  Map<String, dynamic>? customFieldValues = p.containsKey('custom_fields')
                      ? Map<String, dynamic>.from(p['custom_fields'] as Map)
                      : null;
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(flex: 1, child: pw.Text('$index.', style: pw.TextStyle(fontSize: 12))),
                        pw.Expanded(flex: 3, child: pw.Text('${p['entry']}', style: pw.TextStyle(fontSize: 12))),
                        ...customFields.map((field) {
                          String fieldValue = customFieldValues?[field['name']] ?? '-';
                          return pw.Expanded(flex: 2, child: pw.Text(fieldValue, style: pw.TextStyle(fontSize: 12)));
                        }).toList(),
                      ],
                    ),
                  );
                } else {
                  // Simple list format
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: 5),
                    child: pw.Text('$index. ${p['entry']}', style: pw.TextStyle(fontSize: 14)),
                  );
                }
              }).toList(),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Generated: ${DateTime.now().toString().substring(0, 19)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text('Session Link: $shareUrl',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.blue)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Event Session', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: LoadingIndicator(message: 'Loading event details...'),
      );
    }

    if (eventData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('Event Not Found', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        body: ErrorStateWidget(
          title: 'Event Not Found',
          message: 'This event doesn\'t exist or has been deleted.',
          icon: Icons.event_busy_rounded,
          onRetry: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Event Check-In', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          if (!eventEnded)
            IconButton(
              icon: Icon(Icons.stop_circle_rounded),
              onPressed: _endEvent,
              tooltip: 'End Event',
            ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportAsPDF,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Status Banner
              if (eventEnded)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getErrorColor(context).withValues(alpha: 0.1),
                    border: Border.all(color: ThemeHelper.getErrorColor(context)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: ThemeHelper.getErrorColor(context)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This event has ended. No new check-ins allowed.',
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
              if (eventEnded) SizedBox(height: 20),

              // Event Details Card
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFEC4899).withValues(alpha: 0.3),
                      blurRadius: 15,
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
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.celebration_rounded, color: Colors.white, size: 28),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventData!['event_name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '📍 ${eventData!['venue']}',
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
                    SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildInfoChip(Icons.calendar_today_rounded, eventData!['date']),
                        _buildInfoChip(Icons.access_time_rounded, eventData!['time']),
                        _buildInfoChip(Icons.school_rounded, '${eventData!['year']} ${eventData!['branch']}'),
                        if (eventData!.containsKey('capacity'))
                          _buildInfoChip(
                            Icons.people_rounded,
                            '${participants.length}/${eventData!['capacity']}',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // QR Code Section
              Text(
                'QR Code for Quick Check-In',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              SizedBox(height: 12),
              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
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
              SizedBox(height: 24),

              // Share Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _copyLink,
                      icon: Icon(Icons.content_copy_rounded),
                      label: Text('Copy Link'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
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
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),

              // Participants Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Participants',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getSuccessColor(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${participants.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              if (participants.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThemeHelper.getBorderColor(context)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No participants yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Share the link or show QR code',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.getTextTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...participants.map((participant) {
                  // Get custom field values if they exist
                  Map<String, dynamic>? customFieldValues;
                  if (participant.containsKey('custom_fields')) {
                    customFieldValues = Map<String, dynamic>.from(participant['custom_fields'] as Map);
                  }
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThemeHelper.getBorderColor(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              participant['entry'].toString().substring(0, 1).toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ThemeHelper.getPrimaryColor(context),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                participant['entry'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                              // Display custom fields if they exist
                              if (customFieldValues != null && customFieldValues.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: customFieldValues.entries.map((entry) {
                                    return Text(
                                      '${entry.key}: ${entry.value}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: ThemeHelper.getTextSecondary(context),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.check_circle_rounded,
                          color: ThemeHelper.getSuccessColor(context),
                          size: 24,
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
