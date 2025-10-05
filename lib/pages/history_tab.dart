import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendo/pages/StudentViewAttendanceScreen.dart';
import 'package:attendo/pages/EventViewParticipantsScreen.dart';
import 'package:attendo/pages/QuizReportScreen.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Map<String, dynamic>> historyItems = [];
  bool isLoading = true;
  String filter = 'all'; // all, attendance, events, quiz

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      List<Map<String, dynamic>> items = [];

      // Fetch ended attendance sessions
      final attendanceSnapshot = await _dbRef.child('attendance_sessions').get();
      if (attendanceSnapshot.exists) {
        final data = attendanceSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && 
              (session['is_ended'] == true)) {
            items.add({
              'id': key,
              'type': 'attendance',
              'title': session['subject'] ?? 'Untitled',
              'date': session['date'] ?? '',
              'time': session['time'] ?? '',
              'year': session['year'] ?? '',
              'branch': session['branch'] ?? '',
              'division': session['division'] ?? '',
              'count': (session['students'] as Map?)?.length ?? 0,
              'created_at': session['created_at'] ?? '',
              'ended_at': session['ended_at'] ?? '',
            });
          }
        });
      }

      // Fetch ended event sessions
      final eventsSnapshot = await _dbRef.child('event_sessions').get();
      if (eventsSnapshot.exists) {
        final data = eventsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && 
              session['status'] == 'ended') {
            items.add({
              'id': key,
              'type': 'event',
              'title': session['event_name'] ?? 'Untitled Event',
              'venue': session['venue'] ?? '',
              'date': session['date'] ?? '',
              'time': session['time'] ?? '',
              'year': session['year'] ?? '',
              'branch': session['branch'] ?? '',
              'division': session['division'] ?? '',
              'count': (session['participants'] as Map?)?.length ?? 0,
              'created_at': session['created_at'] ?? '',
            });
          }
        });
      }

      // Fetch ended quiz sessions
      final quizSnapshot = await _dbRef.child('quiz_sessions').get();
      if (quizSnapshot.exists) {
        final data = quizSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && 
              session['status'] == 'ended') {
            items.add({
              'id': key,
              'type': 'quiz',
              'title': session['quiz_name'] ?? 'Untitled Quiz',
              'description': session['description'] ?? '',
              'date': session['date'] ?? '',
              'time': session['time'] ?? '',
              'year': session['year'] ?? '',
              'branch': session['branch'] ?? '',
              'division': session['division'] ?? '',
              'count': (session['participants'] as Map?)?.length ?? 0,
              'questions': (session['questions'] as List?)?.length ?? 0,
              'created_at': session['created_at'] ?? '',
            });
          }
        });
      }

      // Sort by creation date (newest first)
      items.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });

      setState(() {
        historyItems = items;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> get filteredItems {
    if (filter == 'all') return historyItems;
    return historyItems.where((item) => item['type'] == filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (value) {
              setState(() => filter = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('All', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'attendance',
                child: Row(
                  children: [
                    Icon(Icons.school_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Attendance', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'event',
                child: Row(
                  children: [
                    Icon(Icons.event_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Events', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quiz',
                child: Row(
                  children: [
                    Icon(Icons.quiz_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Quizzes', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: ThemeHelper.getPrimaryColor(context),
                ),
              )
            : filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 80,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No History Yet',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your ended attendance sessions,\nevents, and quizzes will appear here',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadHistory,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return _buildHistoryCard(context, item);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> item) {
    final type = item['type'];
    IconData icon;
    Color color;
    
    switch (type) {
      case 'attendance':
        icon = Icons.school_rounded;
        color = ThemeHelper.getPrimaryColor(context);
        break;
      case 'event':
        icon = Icons.event_rounded;
        color = ThemeHelper.getSecondaryColor(context);
        break;
      case 'quiz':
        icon = Icons.quiz_rounded;
        color = Colors.deepPurple;
        break;
      default:
        icon = Icons.help_rounded;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (type == 'attendance') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentViewAttendanceScreen(
                  sessionId: item['id'],
                ),
              ),
            );
          } else if (type == 'event') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventViewParticipantsScreen(
                  sessionId: item['id'],
                ),
              ),
            );
          } else if (type == 'quiz') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuizReportScreen(
                  quizId: item['id'],
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (type == 'event' && item['venue'] != '')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['venue'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (type == 'quiz' && item['description'] != '')
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item['description'],
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ended',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    Icons.calendar_today_rounded,
                    item['date'],
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    context,
                    Icons.access_time_rounded,
                    item['time'],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    context,
                    Icons.groups_rounded,
                    '${item['count']} ${type == 'attendance' ? "Present" : "Participants"}',
                  ),
                  if (type == 'quiz')
                    const SizedBox(width: 8),
                  if (type == 'quiz')
                    _buildInfoChip(
                      context,
                      Icons.question_answer_rounded,
                      '${item['questions']} Questions',
                    ),
                  const Spacer(),
                  Text(
                    '${item['year']} ${item['branch']}-${item['division']}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ThemeHelper.getBorderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: ThemeHelper.getTextSecondary(context),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
