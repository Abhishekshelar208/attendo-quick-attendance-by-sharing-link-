import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';

class EventViewParticipantsScreen extends StatefulWidget {
  final String sessionId;
  final String? markedEntry;

  const EventViewParticipantsScreen({
    Key? key,
    required this.sessionId,
    this.markedEntry,
  }) : super(key: key);

  @override
  _EventViewParticipantsScreenState createState() => _EventViewParticipantsScreenState();
}

class _EventViewParticipantsScreenState extends State<EventViewParticipantsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? eventData;
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> filteredParticipants = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEventAndParticipants();
    _setupRealtimeListener();
  }

  void _fetchEventAndParticipants() async {
    try {
      final snapshot = await _dbRef.child('event_sessions/${widget.sessionId}').get();
      if (snapshot.exists) {
        setState(() {
          eventData = Map<String, dynamic>.from(snapshot.value as Map);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching event: $e');
      setState(() => isLoading = false);
    }
  }

  void _setupRealtimeListener() {
    _dbRef.child('event_sessions/${widget.sessionId}/participants').onValue.listen((event) {
      if (event.snapshot.exists) {
        List<Map<String, dynamic>> loadedParticipants = [];
        Map<dynamic, dynamic> participantsMap = event.snapshot.value as Map<dynamic, dynamic>;

        participantsMap.forEach((key, value) {
          Map<String, dynamic> participant = Map<String, dynamic>.from(value as Map);
          participant['id'] = key;
          loadedParticipants.add(participant);
        });

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
          filteredParticipants = loadedParticipants;
          _filterParticipants();
        });
      } else {
        setState(() {
          participants = [];
          filteredParticipants = [];
        });
      }
    });
  }

  void _filterParticipants() {
    String query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => filteredParticipants = participants);
    } else {
      setState(() {
        filteredParticipants = participants.where((p) {
          return p['entry'].toString().toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: LoadingIndicator(message: 'Loading participants...'),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Event Participants', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.markedEntry != null) ...[ 
                ScaleInWidget(
                  duration: Duration(milliseconds: 600),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ThemeHelper.getSuccessColor(context), Colors.green.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeHelper.getSuccessColor(context).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Check-In Successful!',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'You checked in as: ${widget.markedEntry}',
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
                  ),
                ),
                SizedBox(height: 24),
              ],
              if (eventData != null) ...[ 
                SlideInWidget(
                  delay: Duration(milliseconds: widget.markedEntry != null ? 400 : 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventData!['event_name'],
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeHelper.getTextPrimary(context),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${eventData!['venue']} • ${eventData!['date']}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
              // Search bar (only show if more than 5 participants)
              if (participants.length > 5) ...[
                SlideInWidget(
                  delay: Duration(milliseconds: widget.markedEntry != null ? 500 : 200),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ThemeHelper.getBorderColor(context)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterParticipants(),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search participants...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: ThemeHelper.getTextSecondary(context),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterParticipants();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              SlideInWidget(
                delay: Duration(milliseconds: widget.markedEntry != null ? 600 : 300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Participants',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ThemeHelper.getTextPrimary(context),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThemeHelper.getPrimaryColor(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AnimatedCounter(
                        value: filteredParticipants.length,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              if (filteredParticipants.isEmpty && _searchController.text.isNotEmpty)
                FadeInWidget(
                  child: EmptyStateWidget(
                    title: 'No Results',
                    message: 'No participants found matching "${_searchController.text}"',
                    icon: Icons.search_off_rounded,
                  ),
                )
              else if (filteredParticipants.isEmpty)
                FadeInWidget(
                  child: EmptyStateWidget(
                    title: 'No participants yet',
                    message: 'Participants will appear here once they check in',
                    icon: Icons.people_outline_rounded,
                  ),
                )
              else
                ...filteredParticipants.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> p = entry.value;
                  bool isCurrentUser = p['entry'] == widget.markedEntry;
                  
                  return SlideInWidget(
                    delay: Duration(milliseconds: 700 + (index * 50)),
                    begin: Offset(0, 0.03),
                    child: Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1)
                            : ThemeHelper.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrentUser
                              ? ThemeHelper.getPrimaryColor(context)
                              : ThemeHelper.getBorderColor(context),
                          width: isCurrentUser ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? ThemeHelper.getPrimaryColor(context)
                                  : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                p['entry'].toString().substring(0, 1).toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentUser
                                      ? Colors.white
                                      : ThemeHelper.getPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              p['entry'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.getTextPrimary(context),
                              ),
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: ThemeHelper.getPrimaryColor(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'You',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
