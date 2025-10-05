import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool isLoading = true;
  
  // Attendance stats
  int totalAttendanceSessions = 0;
  int totalStudentsMarked = 0;
  double averageAttendance = 0.0;
  
  // Event stats
  int totalEvents = 0;
  int totalEventParticipants = 0;
  double averageEventAttendance = 0.0;
  
  // Quiz stats
  int totalQuizzes = 0;
  int totalQuizParticipants = 0;
  double averageQuizScore = 0.0;
  int totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Load attendance analytics
      await _loadAttendanceAnalytics(currentUser.uid);
      
      // Load event analytics
      await _loadEventAnalytics(currentUser.uid);
      
      // Load quiz analytics
      await _loadQuizAnalytics(currentUser.uid);
      
      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAttendanceAnalytics(String uid) async {
    final snapshot = await _dbRef.child('attendance_sessions').get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    int sessions = 0;
    int students = 0;
    
    data.forEach((key, value) {
      final session = Map<String, dynamic>.from(value as Map);
      if (session['creator_uid'] == uid) {
        sessions++;
        final studentMap = session['students'] as Map?;
        if (studentMap != null) {
          students += studentMap.length;
        }
      }
    });

    setState(() {
      totalAttendanceSessions = sessions;
      totalStudentsMarked = students;
      averageAttendance = sessions > 0 ? students / sessions : 0.0;
    });
  }

  Future<void> _loadEventAnalytics(String uid) async {
    final snapshot = await _dbRef.child('event_sessions').get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    int events = 0;
    int participants = 0;
    
    data.forEach((key, value) {
      final session = Map<String, dynamic>.from(value as Map);
      if (session['creator_uid'] == uid) {
        events++;
        final participantMap = session['participants'] as Map?;
        if (participantMap != null) {
          participants += participantMap.length;
        }
      }
    });

    setState(() {
      totalEvents = events;
      totalEventParticipants = participants;
      averageEventAttendance = events > 0 ? participants / events : 0.0;
    });
  }

  Future<void> _loadQuizAnalytics(String uid) async {
    final snapshot = await _dbRef.child('quiz_sessions').get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<dynamic, dynamic>;
    int quizzes = 0;
    int participants = 0;
    int totalScore = 0;
    int scoreCount = 0;
    int questions = 0;
    
    data.forEach((key, value) {
      final session = Map<String, dynamic>.from(value as Map);
      if (session['creator_uid'] == uid) {
        quizzes++;
        
        final questionList = session['questions'] as List?;
        if (questionList != null) {
          questions += questionList.length;
        }
        
        final participantMap = session['participants'] as Map?;
        if (participantMap != null) {
          participants += participantMap.length;
          
          participantMap.forEach((pKey, pValue) {
            final participant = pValue as Map?;
            if (participant != null && participant['score'] != null) {
              totalScore += participant['score'] as int;
              scoreCount++;
            }
          });
        }
      }
    });

    setState(() {
      totalQuizzes = quizzes;
      totalQuizParticipants = participants;
      totalQuestions = questions;
      averageQuizScore = scoreCount > 0 ? totalScore / scoreCount : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasData = totalAttendanceSessions > 0 || totalEvents > 0 || totalQuizzes > 0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnalytics,
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
            : !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          size: 80,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Data Available',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create attendance, events, or quizzes\nto view analytics and insights',
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
                    onRefresh: _loadAnalytics,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview Cards
                          Text(
                            'Overview',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ThemeHelper.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildOverviewCard(
                                  context,
                                  'Attendance',
                                  totalAttendanceSessions.toString(),
                                  Icons.school_rounded,
                                  ThemeHelper.getPrimaryColor(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildOverviewCard(
                                  context,
                                  'Events',
                                  totalEvents.toString(),
                                  Icons.event_rounded,
                                  ThemeHelper.getSecondaryColor(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildOverviewCard(
                                  context,
                                  'Quizzes',
                                  totalQuizzes.toString(),
                                  Icons.quiz_rounded,
                                  Colors.deepPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Attendance Analytics
                          if (totalAttendanceSessions > 0) ...[
                            _buildSectionHeader(context, 'Attendance Analytics', Icons.school_rounded),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Sessions',
                              totalAttendanceSessions.toString(),
                              Icons.event_note_rounded,
                              ThemeHelper.getPrimaryColor(context),
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Students Marked',
                              totalStudentsMarked.toString(),
                              Icons.people_rounded,
                              Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Average per Session',
                              averageAttendance.toStringAsFixed(1),
                              Icons.bar_chart_rounded,
                              Colors.green,
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Event Analytics
                          if (totalEvents > 0) ...[
                            _buildSectionHeader(context, 'Event Analytics', Icons.event_rounded),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Events',
                              totalEvents.toString(),
                              Icons.celebration_rounded,
                              ThemeHelper.getSecondaryColor(context),
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Participants',
                              totalEventParticipants.toString(),
                              Icons.people_alt_rounded,
                              Colors.orange,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Average per Event',
                              averageEventAttendance.toStringAsFixed(1),
                              Icons.trending_up_rounded,
                              Colors.teal,
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Quiz Analytics
                          if (totalQuizzes > 0) ...[
                            _buildSectionHeader(context, 'Quiz Analytics', Icons.quiz_rounded),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Quizzes',
                              totalQuizzes.toString(),
                              Icons.quiz_rounded,
                              Colors.deepPurple,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Participants',
                              totalQuizParticipants.toString(),
                              Icons.people_rounded,
                              Colors.indigo,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Total Questions',
                              totalQuestions.toString(),
                              Icons.question_answer_rounded,
                              Colors.purple,
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              context,
                              'Average Score',
                              averageQuizScore.toStringAsFixed(1),
                              Icons.grade_rounded,
                              Colors.amber,
                            ),
                            const SizedBox(height: 12),
                            if (totalQuizParticipants > 0)
                              _buildStatCard(
                                context,
                                'Avg Participants per Quiz',
                                (totalQuizParticipants / totalQuizzes).toStringAsFixed(1),
                                Icons.analytics_rounded,
                                Colors.blueGrey,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: ThemeHelper.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: ThemeHelper.getTextPrimary(context)),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ThemeHelper.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: ThemeHelper.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
