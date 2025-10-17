import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:html' as html show Blob, AnchorElement, Url;

class InstantDataViewScreen extends StatefulWidget {
  final String sessionId;

  const InstantDataViewScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _InstantDataViewScreenState createState() => _InstantDataViewScreenState();
}

class _InstantDataViewScreenState extends State<InstantDataViewScreen> {
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
      final snapshot = await _dbRef.child('instant_data_collection/${widget.sessionId}').get();

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
        
        print('✅ Session loaded: ${data['title']}');
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

    _dbRef.child('instant_data_collection/${widget.sessionId}/responses').onValue.listen((event) {
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

    // Handle checkboxes (list of values)
    if (value is List) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: value.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xfff59e0b).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.toString(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xfff59e0b),
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

  void _exportAsPDF() async {
    if (sessionData == null || responses.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'No data to export',
        type: SnackBarType.error,
      );
      return;
    }

    print('📄 Generating PDF...');

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Text(
              'Instant Data Collection Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Session: ${sessionData!['title']}', style: pw.TextStyle(fontSize: 16)),
            if (sessionData!['description'].toString().isNotEmpty)
              pw.Text('Description: ${sessionData!['description']}', style: pw.TextStyle(fontSize: 14)),
            pw.Text('Created: ${_formatTimestamp(sessionData!['created_at'])}', style: pw.TextStyle(fontSize: 14)),
            pw.Text('Status: ${sessionData!['status']}', style: pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('Total Responses: ${responses.length}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('Response Details:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 15),
            
            // Build table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
              columnWidths: {
                0: const pw.FixedColumnWidth(40), // Response #
                1: const pw.FixedColumnWidth(90), // Timestamp
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('#', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Timestamp', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ),
                    ...customFields.map((field) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        field['name'],
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    )).toList(),
                  ],
                ),
                // Data rows
                ...responses.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> response = entry.value;
                  Map<String, dynamic>? fieldValues = response.containsKey('field_values')
                      ? Map<String, dynamic>.from(response['field_values'] as Map)
                      : null;

                  return pw.TableRow(
                    decoration: index.isEven ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _formatTimestamp(response['timestamp'] ?? ''),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      ...customFields.map((field) {
                        String fieldName = field['name'];
                        dynamic fieldValue = fieldValues?[fieldName];
                        String displayValue = fieldValue != null ? fieldValue.toString() : '-';
                        
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            displayValue,
                            style: const pw.TextStyle(fontSize: 10),
                            maxLines: 3,
                            overflow: pw.TextOverflow.clip,
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('Generated: ${DateTime.now().toString().substring(0, 19)}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ];
        },
      ),
    );

    if (kIsWeb) {
      // Web: Download PDF directly
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'instant_data_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
      
      EnhancedSnackBar.show(
        context,
        message: 'PDF downloaded successfully! 📄',
        type: SnackBarType.success,
      );
    } else {
      // Mobile/Desktop: Use printing package
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      
      EnhancedSnackBar.show(
        context,
        message: 'PDF generated successfully! 📄',
        type: SnackBarType.success,
      );
    }

    print('✅ PDF generated');
  }

  void _exportAsCSV() async {
    if (sessionData == null || responses.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'No data to export',
        type: SnackBarType.error,
      );
      return;
    }

    print('📊 Generating CSV...');

    List<List<dynamic>> csvData = [];

    // Header row
    List<String> headers = ['Response #', 'Timestamp', 'Device ID'];
    for (var field in customFields) {
      headers.add(field['name']);
    }
    csvData.add(headers);

    // Data rows
    for (int i = 0; i < responses.length; i++) {
      Map<String, dynamic> response = responses[i];
      Map<String, dynamic>? fieldValues = response.containsKey('field_values')
          ? Map<String, dynamic>.from(response['field_values'] as Map)
          : null;

      List<dynamic> row = [
        i + 1,
        response['timestamp'] ?? 'N/A',
        response['device_id']?.substring(0, 20) ?? 'N/A',
      ];

      if (fieldValues != null) {
        for (var field in customFields) {
          String fieldName = field['name'];
          dynamic fieldValue = fieldValues[fieldName];
          row.add(fieldValue?.toString() ?? '');
        }
      }

      csvData.add(row);
    }

    // Convert to CSV string
    String csvString = const ListToCsvConverter().convert(csvData);
    final fileName = 'instant_data_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}.csv';

    // Save to file
    try {
      if (kIsWeb) {
        // Web: Download CSV directly
        final bytes = utf8.encode(csvString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        EnhancedSnackBar.show(
          context,
          message: 'CSV downloaded successfully! 📊',
          type: SnackBarType.success,
        );
        
        print('✅ CSV downloaded: $fileName');
      } else {
        // Mobile/Desktop: Save and share
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csvString);

        print('✅ CSV saved to: $path');

        // Share the file
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Instant Data Collection - ${sessionData!['title']}',
        );

        EnhancedSnackBar.show(
          context,
          message: 'CSV exported successfully! 📊',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      print('❌ Error exporting CSV: $e');
      EnhancedSnackBar.show(
        context,
        message: 'Error exporting CSV',
        type: SnackBarType.error,
      );
    }
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

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Responses', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        actions: [
          if (responses.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.table_chart_rounded),
              onPressed: _exportAsCSV,
              tooltip: 'Export CSV',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _exportAsPDF,
              tooltip: 'Export PDF',
            ),
          ],
        ],
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
                gradient: const LinearGradient(
                  colors: [Color(0xfff59e0b), Color(0xfffbbf24)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xfff59e0b).withValues(alpha: 0.3),
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
                      const Icon(
                        Icons.poll_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sessionData!['title'],
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
                                  color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xfff59e0b),
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
                                              color: const Color(0xfff59e0b).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              _getFieldIcon(fieldType),
                                              color: const Color(0xfff59e0b),
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
