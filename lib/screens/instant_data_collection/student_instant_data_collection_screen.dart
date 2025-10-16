import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendo/widgets/custom_field_widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class StudentInstantDataCollectionScreen extends StatefulWidget {
  final String sessionId;

  const StudentInstantDataCollectionScreen({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  _StudentInstantDataCollectionScreenState createState() =>
      _StudentInstantDataCollectionScreenState();
}

class _StudentInstantDataCollectionScreenState
    extends State<StudentInstantDataCollectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Map<String, dynamic> _fieldValues = {};

  Map<String, dynamic>? _sessionData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  String _deviceFingerprint = '';

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _generateDeviceFingerprint();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _generateDeviceFingerprint() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String fingerprint;

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        fingerprint =
            '${webInfo.browserName}_${webInfo.platform}_${webInfo.userAgent}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprint = androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprint = iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        fingerprint = 'unknown_device';
      }

      setState(() {
        _deviceFingerprint = fingerprint;
      });
    } catch (e) {
      print('Error generating device fingerprint: $e');
      setState(() {
        _deviceFingerprint = 'error_${DateTime.now().millisecondsSinceEpoch}';
      });
    }
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
      } else {
        setState(() {
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

  Future<void> _submitResponse() async {
    // Validation
    if (_sessionData == null) return;

    final collectName = _sessionData!['collectName'] ?? true;
    if (collectName && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate required custom fields
    final customFields =
        _sessionData!['customFields'] as List<dynamic>? ?? [];
    for (var field in customFields) {
      final fieldName = field['name'] as String;
      final isRequired = field['required'] as bool? ?? true;

      if (isRequired &&
          (!_fieldValues.containsKey(fieldName) ||
              _fieldValues[fieldName] == null ||
              _fieldValues[fieldName].toString().trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in: $fieldName'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create submission document
      await FirebaseFirestore.instance
          .collection('instant_data_collection')
          .doc(widget.sessionId)
          .collection('submissions')
          .add({
        'studentName': collectName ? _nameController.text.trim() : 'Anonymous',
        'responses': _fieldValues,
        'deviceFingerprint': _deviceFingerprint,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _hasSubmitted = true;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Response submitted successfully!'),
          backgroundColor: ThemeHelper.getSuccessColor(context),
        ),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting response: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Session Not Found',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This session does not exist or has been deleted',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final status = _sessionData!['status'] ?? 'active';
    if (status != 'active') {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Session Closed',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This session is no longer accepting responses',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_hasSubmitted) {
      final allowMultiple = _sessionData!['allowMultipleSubmissions'] ?? false;

      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getSuccessColor(context).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: ThemeHelper.getSuccessColor(context),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Submitted Successfully!',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Thank you for your response',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (allowMultiple) ...[
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasSubmitted = false;
                        _nameController.clear();
                        _fieldValues.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Submit Another Response',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final collectName = _sessionData!['collectName'] ?? true;
    final customFields = _sessionData!['customFields'] as List<dynamic>? ?? [];
    final title = _sessionData!['title'] ?? 'Data Collection';
    final description = _sessionData!['description'] ?? '';

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: ThemeHelper.getPrimaryColor(context),
      ),
      body: _isSubmitting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ThemeHelper.getPrimaryColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Submitting your response...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Info Card
                  if (description.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        border: Border.all(
                          color: ThemeHelper.getBorderColor(context),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_rounded,
                                color: ThemeHelper.getPrimaryColor(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: ThemeHelper.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Name Field (if enabled)
                  if (collectName) ...[
                    Text(
                      'Your Name',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          ' *',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: ThemeHelper.getCardColor(context),
                        border: Border.all(
                          color: ThemeHelper.getBorderColor(context),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your name',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.getTextTertiary(context),
                          ),
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: ThemeHelper.getPrimaryColor(context),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Custom Fields
                  if (customFields.isNotEmpty) ...[
                    Text(
                      'Response Fields',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...customFields.map((field) {
                      final fieldConfig = field as Map<String, dynamic>;
                      return CustomFieldWidget(
                        fieldConfig: fieldConfig,
                        onValueChanged: (fieldName, value) {
                          setState(() {
                            _fieldValues[fieldName] = value;
                          });
                        },
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitResponse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeHelper.getPrimaryColor(context),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Submit Response',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
