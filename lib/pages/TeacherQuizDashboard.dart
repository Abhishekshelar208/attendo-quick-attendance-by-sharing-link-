import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'QuizReportScreen.dart';

class TeacherQuizDashboard extends StatefulWidget {
  final String quizId;

  const TeacherQuizDashboard({Key? key, required this.quizId}) : super(key: key);

  @override
  _TeacherQuizDashboardState createState() => _TeacherQuizDashboardState();
}

class _TeacherQuizDashboardState extends State<TeacherQuizDashboard> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? quizData;
  Map<String, dynamic> participants = {};
  bool isLoading = true;
  String quizStatus = 'active';

  @override
  void initState() {
    super.initState();
    _loadQuizData();
    _listenToParticipants();
    _listenToQuizStatus();
  }

  Future<void> _loadQuizData() async {
    try {
      final snapshot = await _database.child('quiz_sessions/${widget.quizId}').get();
      if (snapshot.exists) {
        setState(() {
          quizData = Map<String, dynamic>.from(snapshot.value as Map);
          isLoading = false;
        });
      } else {
        _showError('Quiz not found');
      }
    } catch (e) {
      _showError('Error loading quiz: $e');
    }
  }

  void _listenToParticipants() {
    _database.child('quiz_sessions/${widget.quizId}/participants').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          participants = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          participants = {};
        });
      }
    });
  }

  void _listenToQuizStatus() {
    _database.child('quiz_sessions/${widget.quizId}/status').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          quizStatus = event.snapshot.value.toString();
        });
      }
    });
  }

  Future<void> _endQuiz() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Quiz?'),
        content: const Text('Are you sure you want to end this quiz? Students will no longer be able to submit answers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End Quiz'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _database.child('quiz_sessions/${widget.quizId}/status').set('ended');
        await _database.child('quiz_sessions/${widget.quizId}/ended_at').set(DateTime.now().toIso8601String());
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz ended successfully'), backgroundColor: Colors.green),
        );
      } catch (e) {
        _showError('Error ending quiz: $e');
      }
    }
  }

  void _viewReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizReportScreen(quizId: widget.quizId),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  int _getCompletedCount() {
    return participants.values.where((p) {
      final answers = p['answers'] as List?;
      final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;
      return answers != null && answers.length == totalQuestions;
    }).length;
  }

  int _getInProgressCount() {
    return participants.values.where((p) {
      final answers = p['answers'] as List?;
      final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;
      return answers != null && answers.isNotEmpty && answers.length < totalQuestions;
    }).length;
  }

  int _getNotStartedCount() {
    return participants.values.where((p) {
      final answers = p['answers'] as List?;
      return answers == null || answers.isEmpty;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Dashboard'),
          backgroundColor: const Color(0xff8b5cf6),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;
    final totalParticipants = participants.length;
    final completedCount = _getCompletedCount();
    final inProgressCount = _getInProgressCount();
    final notStartedCount = _getNotStartedCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Dashboard'),
        backgroundColor: const Color(0xff8b5cf6),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'View Report',
            onPressed: _viewReport,
          ),
          if (quizStatus == 'active')
            IconButton(
              icon: const Icon(Icons.stop_circle),
              tooltip: 'End Quiz',
              onPressed: _endQuiz,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuizData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz Info Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quizData?['quiz_name'] ?? 'Quiz',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          _buildStatusChip(quizStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        quizData?['description'] ?? '',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          _buildInfoChip(Icons.calendar_today, quizData?['date'] ?? ''),
                          const SizedBox(width: 8),
                          _buildInfoChip(Icons.access_time, quizData?['time'] ?? ''),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildInfoChip(Icons.school, '${quizData?['year']} ${quizData?['branch']}'),
                          const SizedBox(width: 8),
                          _buildInfoChip(Icons.people, 'Div ${quizData?['division']}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Statistics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Participants',
                      totalParticipants.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Questions',
                      totalQuestions.toString(),
                      Icons.quiz,
                      const Color(0xff8b5cf6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Completed',
                      completedCount.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'In Progress',
                      inProgressCount.toString(),
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Not Started',
                      notStartedCount.toString(),
                      Icons.hourglass_empty,
                      Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Participants List
              Text(
                'Participants (${totalParticipants})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              if (totalParticipants == 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No participants yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share the quiz link to get started',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalParticipants,
                  itemBuilder: (context, index) {
                    final participantId = participants.keys.elementAt(index);
                    final participant = participants[participantId];
                    return _buildParticipantCard(participantId, participant, totalQuestions);
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: quizStatus == 'active'
          ? FloatingActionButton.extended(
              onPressed: _endQuiz,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop),
              label: const Text('End Quiz'),
            )
          : null,
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.play_circle_fill : Icons.stop_circle,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Active' : 'Ended',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantCard(String participantId, dynamic participant, int totalQuestions) {
    final customFieldValues = participant['custom_field_values'] as Map?;
    final answers = participant['answers'] as List?;
    final score = participant['score'];
    final rank = participant['rank'];

    final answeredCount = answers?.length ?? 0;
    final progress = totalQuestions > 0 ? answeredCount / totalQuestions : 0.0;

    String status;
    Color statusColor;
    IconData statusIcon;

    if (answeredCount == totalQuestions) {
      status = 'Completed';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (answeredCount > 0) {
      status = 'In Progress ($answeredCount/$totalQuestions)';
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    } else {
      status = 'Not Started';
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(statusIcon, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customFieldValues?['Name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      if (customFieldValues != null)
                        ...customFieldValues.entries.where((e) => e.key != 'Name').map(
                          (e) => Text(
                            '${e.key}: ${e.value}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xff8b5cf6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$score/$totalQuestions',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xff8b5cf6),
                          ),
                        ),
                        if (rank != null)
                          Text(
                            'Rank #$rank',
                            style: const TextStyle(fontSize: 10, color: const Color(0xff8b5cf6)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
