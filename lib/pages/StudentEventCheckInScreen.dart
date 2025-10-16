import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:attendo/widgets/custom_field_widgets.dart';
import 'package:attendo/services/device_fingerprint_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'EventViewParticipantsScreen.dart';
import 'package:lottie/lottie.dart';

class StudentEventCheckInScreen extends StatefulWidget {
  final String sessionId;

  const StudentEventCheckInScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  _StudentEventCheckInScreenState createState() => _StudentEventCheckInScreenState();
}

class _StudentEventCheckInScreenState extends State<StudentEventCheckInScreen> {
  final TextEditingController _entryController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Map<String, dynamic> _customFieldValues = {}; // Changed from controllers to values
  Map<String, dynamic>? eventData;
  bool isLoading = true;
  bool isSubmitting = false;
  String? alreadyMarkedEntry;
  List<Map<String, dynamic>> customFields = [];

  @override
  void initState() {
    super.initState();
    _checkDeviceAndLoadEvent();
  }

  void _checkDeviceAndLoadEvent() async {
    print('📱 Opening event: ${widget.sessionId}');

    // Get device fingerprint
    String deviceId = await DeviceFingerprintService.getFingerprint();
    print('🔐 Device ID: ${deviceId.substring(0, 20)}...');

    // Check if device already checked in
    await _checkIfDeviceAlreadyCheckedIn(deviceId);
  }

  Future<void> _checkIfDeviceAlreadyCheckedIn(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    String storageKey = 'event_checkin_${widget.sessionId}';
    
    // Check localStorage first (fast)
    String? localEntry = prefs.getString(storageKey);
    if (localEntry != null) {
      print('💾 Found local check-in: $localEntry');
      
      // Verify in Firebase (authoritative) - query all and check manually
      final snapshot = await _dbRef
          .child('event_sessions/${widget.sessionId}/participants')
          .get();

      bool found = false;
      String? foundEntry;
      
      if (snapshot.exists) {
        final participantsMap = snapshot.value as Map;
        for (var participant in participantsMap.values) {
          if (participant['device_id'] == deviceId) {
            found = true;
            foundEntry = participant['entry'];
            break;
          }
        }
      }

      if (found) {
        print('✅ Device already checked in (verified in Firebase)');
        
        setState(() {
          alreadyMarkedEntry = foundEntry;
          isLoading = false;
        });

        // Show message and redirect after animation
        await Future.delayed(Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            SmoothPageRoute(
              page: EventViewParticipantsScreen(
                sessionId: widget.sessionId,
                markedEntry: alreadyMarkedEntry,
              ),
            ),
          );
        }
        return;
      }
    }

    // Device not checked in, load event details
    _fetchEventDetails();
  }

  void _fetchEventDetails() async {
    print('📚 Fetching event details for: ${widget.sessionId}');

    try {
      final snapshot = await _dbRef.child('event_sessions/${widget.sessionId}').get();

      if (snapshot.exists) {
        Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Parse custom fields if they exist
        if (data.containsKey('custom_fields')) {
          customFields = List<Map<String, dynamic>>.from(
            (data['custom_fields'] as List).map((f) => Map<String, dynamic>.from(f))
          );
        }
        
        setState(() {
          eventData = data;
          isLoading = false;
        });

        print('✅ Event loaded: ${data['event_name']} (${data['input_type']})');
        print('   Custom fields: ${customFields.length}');

        // Don't show dialog - the UI will handle ended state
      } else {
        print('⚠️ Event not found!');
        setState(() => isLoading = false);
        _showErrorDialog('Event not found or has been deleted.');
      }
    } catch (e) {
      print('❌ Error loading event: $e');
      setState(() => isLoading = false);
      _showErrorDialog('Error loading event. Please check your connection.');
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

  void _submitCheckIn() async {
    String entry = _entryController.text.trim();

    if (entry.isEmpty) {
      EnhancedSnackBar.show(
        context,
        message: 'Please enter your ${eventData!['input_type']}',
        type: SnackBarType.error,
      );
      return;
    }
    
    // Validate custom fields
    print('🔍 Validating custom fields...');
    print('   Total custom fields: ${customFields.length}');
    print('   Values in map: ${_customFieldValues.length}');
    print('   All values: $_customFieldValues');
    
    for (var field in customFields) {
      String fieldName = field['name'];
      String fieldType = field['type'] ?? 'text';
      bool isRequired = field['required'] ?? true;
      
      print('   Checking field: $fieldName (type: $fieldType, required: $isRequired)');
      
      if (isRequired) {
        dynamic value = _customFieldValues[fieldName];
        print('     Value: $value');
        
        if (value == null || value.toString().trim().isEmpty) {
          print('     ❌ VALIDATION FAILED: Value is empty!');
          EnhancedSnackBar.show(
            context,
            message: 'Please fill in $fieldName',
            type: SnackBarType.error,
          );
          return;
        }
        print('     ✅ Validation passed');
      }
    }
    print('✅ All custom fields validated successfully!');
    

    // Check capacity limit
    if (eventData!.containsKey('capacity')) {
      final participantsSnapshot = await _dbRef
          .child('event_sessions/${widget.sessionId}/participants')
          .get();
      
      int currentCount = 0;
      if (participantsSnapshot.exists) {
        currentCount = (participantsSnapshot.value as Map).length;
      }

      if (currentCount >= eventData!['capacity']) {
        EnhancedSnackBar.show(
          context,
          message: 'Event is full! Capacity reached (${eventData!['capacity']})',
          type: SnackBarType.error,
        );
        return;
      }
    }

    setState(() => isSubmitting = true);

    print('✍️ Submitting check-in...');
    print('   Event: ${widget.sessionId}');
    print('   Entry: $entry');

    try {
      // Get device fingerprint
      String deviceId = await DeviceFingerprintService.getFingerprint();
      print('   Device ID: ${deviceId.substring(0, 20)}...');

      // Double-check device hasn't checked in (race condition protection)
      // Query all participants and check manually (more reliable)
      final allParticipantsSnapshot = await _dbRef
          .child('event_sessions/${widget.sessionId}/participants')
          .get();
      
      bool deviceAlreadyCheckedIn = false;
      String? existingEntry;
      
      if (allParticipantsSnapshot.exists) {
        final participantsMap = allParticipantsSnapshot.value as Map;
        for (var participant in participantsMap.values) {
          if (participant['device_id'] == deviceId) {
            deviceAlreadyCheckedIn = true;
            existingEntry = participant['entry'];
            break;
          }
        }
      }

      if (deviceAlreadyCheckedIn) {
        print('⚠️ Device already checked in!');
        print('   Existing entry: $existingEntry');
        
        setState(() => isSubmitting = false);
        
        EnhancedSnackBar.show(
          context,
          message: 'You already checked in as: $existingEntry',
          type: SnackBarType.warning,
        );

        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            SmoothPageRoute(
              page: EventViewParticipantsScreen(
                sessionId: widget.sessionId,
                markedEntry: existingEntry,
              ),
            ),
          );
        }
        return;
      }

      // Submit check-in
      DatabaseReference participantRef = _dbRef
          .child('event_sessions/${widget.sessionId}/participants')
          .push();

      Map<String, dynamic> participantData = {
        'entry': entry,
        'device_id': deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Add custom field values
      if (_customFieldValues.isNotEmpty) {
        participantData['custom_fields'] = _customFieldValues;
      }

      await participantRef.set(participantData);

      // Save to localStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('event_checkin_${widget.sessionId}', entry);

      print('✅ Check-in successful!');

      setState(() => isSubmitting = false);

      // Show success message
      EnhancedSnackBar.show(
        context,
        message: 'Check-in successful! 🎉',
        type: SnackBarType.success,
      );

      // Navigate to view participants screen with smooth transition
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          SmoothPageRoute(
            page: EventViewParticipantsScreen(
              sessionId: widget.sessionId,
              markedEntry: entry,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error submitting check-in: $e');
      print('Stack trace: $stackTrace');
      setState(() => isSubmitting = false);

      EnhancedSnackBar.show(
        context,
        message: 'Error checking in. Please try again.',
        type: SnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    // Custom field values are stored directly, no controllers to dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: alreadyMarkedEntry != null ? ThemeHelper.getBackgroundColor(context) : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (alreadyMarkedEntry != null) ...[
                SuccessAnimation(
                  size: 120,
                  color: ThemeHelper.getSuccessColor(context),
                ),
                SizedBox(height: 24),
                FadeInWidget(
                  delay: Duration(milliseconds: 400),
                  child: Text(
                    'Already checked in!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                FadeInWidget(
                  delay: Duration(milliseconds: 600),
                  child: Text(
                    alreadyMarkedEntry!,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.getPrimaryColor(context),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                FadeInWidget(
                  delay: Duration(milliseconds: 800),
                  child: Text(
                    'Redirecting...',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                ),
              ] else ...[
                Lottie.asset(
                  'lib/assets/animations/runningcuteanimation.json',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (eventData == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: ErrorStateWidget(
          title: 'Event Not Found',
          message: 'This event doesn\'t exist or has been deleted.',
          icon: Icons.event_busy_rounded,
          onRetry: () => Navigator.pop(context),
        ),
      );
    }

    // Check if event has ended
    bool isEventEnded = eventData!['status'] == 'ended';

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Event Check-In', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: isEventEnded
            ? _buildEndedView()
            : SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Card
              SlideInWidget(
                delay: Duration(milliseconds: 100),
                child: Container(
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
                          child: Icon(Icons.celebration_rounded, color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eventData!['event_name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
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
                      ],
                    ),
                  ],
                ),
                ),
              ),
              SizedBox(height: 40),

              // Check-in Form
              SlideInWidget(
                delay: Duration(milliseconds: 300),
                child: Text(
                'Enter Your Details',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ThemeHelper.getTextPrimary(context),
                ),
                ),
              ),
              SizedBox(height: 8),
              SlideInWidget(
                delay: Duration(milliseconds: 350),
                child: Text(
                'You\'ll be able to view all participants after check-in',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.getTextSecondary(context),
                ),
                ),
              ),
              SizedBox(height: 24),

              // Input Field
              SlideInWidget(
                delay: Duration(milliseconds: 400),
                child: Container(
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _entryController,
                  enabled: !isSubmitting,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: eventData!['input_type'] == 'Roll Number'
                        ? 'e.g., 22, 101'
                        : eventData!['input_type'] == 'Name'
                            ? 'e.g., John Doe'
                            : eventData!['input_type'] == 'Email'
                                ? 'e.g., student@college.edu'
                                : 'e.g., +91 9876543210',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      color: ThemeHelper.getTextTertiary(context),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      eventData!['input_type'] == 'Roll Number'
                          ? Icons.numbers_rounded
                          : eventData!['input_type'] == 'Name'
                              ? Icons.person_rounded
                              : eventData!['input_type'] == 'Email'
                                  ? Icons.email_rounded
                                  : Icons.phone_rounded,
                      color: ThemeHelper.getPrimaryColor(context),
                      size: 28,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  ),
                  keyboardType: eventData!['input_type'] == 'Roll Number'
                      ? TextInputType.number
                      : eventData!['input_type'] == 'Email'
                          ? TextInputType.emailAddress
                          : eventData!['input_type'] == 'Phone'
                              ? TextInputType.phone
                              : TextInputType.text,
                ),
                ),
              ),
              SizedBox(height: 24),

              // Custom Fields - Using CustomFieldWidget
              ...customFields.map((field) {
                return SlideInWidget(
                  delay: Duration(milliseconds: 500 + (customFields.indexOf(field) * 100)),
                  child: CustomFieldWidget(
                    fieldConfig: field,
                    enabled: !isSubmitting,
                    onValueChanged: (fieldName, value) {
                      print('📝 Custom field value changed: $fieldName = $value');
                      setState(() {
                        _customFieldValues[fieldName] = value;
                      });
                      print('✅ Value stored in map. Total fields: ${_customFieldValues.length}');
                      print('   Current values: $_customFieldValues');
                    },
                  ),
                );
              }).toList(),
              if (customFields.isNotEmpty) SizedBox(height: 8),

              // Check-in Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submitCheckIn,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Check In Now',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 24),

              // Device Lock Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
                  border: Border.all(
                    color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: ThemeHelper.getPrimaryColor(context),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can only check in once per device. Make sure your details are correct.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildEndedView() {
    // Fetch participants count and list
    int participantCount = 0;
    List<String> participants = [];
    
    if (eventData!.containsKey('participants')) {
      final participantsData = eventData!['participants'] as Map;
      participantCount = participantsData.length;
      participants = participantsData.values
          .map((p) => p['entry'].toString())
          .toList();
      
      // Sort participants
      participants.sort((a, b) {
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) {
          return aNum.compareTo(bNum);
        }
        return a.compareTo(b);
      });
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 20),
          
          // Event Ended Icon
          Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThemeHelper.getWarningColor(context),
                    ThemeHelper.getWarningColor(context).withValues(alpha: 0.8),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 30),
          
          // Event Ended Card
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThemeHelper.getWarningColor(context).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Event Ended',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'This event has ended and is no longer accepting check-ins',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // Event Details Card
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ThemeHelper.getCardColor(context),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: ThemeHelper.getShadowColor(context),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 20),
                _buildDetailRow(Icons.celebration_rounded, 'Event', eventData!['event_name']),
                SizedBox(height: 16),
                _buildDetailRow(Icons.location_on_rounded, 'Venue', eventData!['venue']),
                SizedBox(height: 16),
                _buildDetailRow(Icons.calendar_today_rounded, 'Date', eventData!['date']),
                SizedBox(height: 16),
                _buildDetailRow(Icons.access_time_rounded, 'Time', eventData!['time']),
                SizedBox(height: 16),
                _buildDetailRow(Icons.school_rounded, 'Class', '${eventData!['year']} ${eventData!['branch']}'),
                SizedBox(height: 16),
                _buildDetailRow(
                  Icons.people_rounded,
                  'Total Checked In',
                  participantCount.toString(),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          
          // Participants Section
          if (participantCount > 0) ...[
            Text(
              'Checked In Participants',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ThemeHelper.getTextPrimary(context),
              ),
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: ThemeHelper.getShadowColor(context),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: participants.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: ThemeHelper.getBorderColor(context),
                ),
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: ThemeHelper.getPrimaryGradient(context),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      participants[index],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ThemeHelper.getBorderColor(context),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: ThemeHelper.getTextTertiary(context),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No participants checked in',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: ThemeHelper.getPrimaryColor(context),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: ThemeHelper.getTextSecondary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: ThemeHelper.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
