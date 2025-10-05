import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/models/quiz_models.dart';

class QuizResultsScreen extends StatefulWidget {
  final String quizId;
  final String participantId;

  const QuizResultsScreen({
    Key? key,
    required this.quizId,
    required this.participantId,
  }) : super(key: key);

  @override
  _QuizResultsScreenState createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Map<String, dynamic>> participants = [];
  Map<String, dynamic>? currentParticipant;
  QuizSession? quizSession;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
    _listenForUpdates();
  }

  Future<void> _loadResults() async {
    try {
      // Load quiz session
      final quizSnapshot = await _dbRef.child('quiz_sessions/${widget.quizId}').get();
      if (!quizSnapshot.exists) return;

      final quizData = Map<String, dynamic>.from(quizSnapshot.value as Map);
      final quiz = QuizSession.fromJson(widget.quizId, quizData);

      // Load all participants
      final participantsData = quizData['participants'] as Map<dynamic, dynamic>?;
      if (participantsData == null) return;

      List<Map<String, dynamic>> participantsList = [];
      participantsData.forEach((key, value) {
        final participant = Map<String, dynamic>.from(value as Map);
        participant['id'] = key;
        participantsList.add(participant);
      });

      // Sort by score (high to low)
      participantsList.sort((a, b) {
        final scoreA = a['score'] ?? 0;
        final scoreB = b['score'] ?? 0;
        return scoreB.compareTo(scoreA);
      });

      // Assign ranks
      for (int i = 0; i < participantsList.length; i++) {
        participantsList[i]['rank'] = i + 1;
      }

      // Find current participant
      final current = participantsList.firstWhere(
        (p) => p['id'] == widget.participantId,
        orElse: () => {},
      );

      setState(() {
        quizSession = quiz;
        participants = participantsList;
        currentParticipant = current;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading results: $e');
      setState(() => isLoading = false);
    }
  }

  void _listenForUpdates() {
    _dbRef.child('quiz_sessions/${widget.quizId}/participants').onValue.listen((event) {
      if (mounted) {
        _loadResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        body: Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Quiz Results',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Your Score Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Score',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentParticipant?['score'] ?? 0}/${quizSession?.questions.length ?? 0}',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Rank ${currentParticipant?['rank'] ?? 0} of ${participants.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Leaderboard Title
              Row(
                children: [
                  const Icon(Icons.leaderboard_rounded, color: Colors.purple),
                  const SizedBox(width: 12),
                  Text(
                    'Leaderboard',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ThemeHelper.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Top 3 Winners (if available)
              if (participants.length >= 3) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd Place
                    _buildPodiumCard(participants[1], 2, const Color(0xffc0c0c0)),
                    const SizedBox(width: 8),
                    // 1st Place
                    _buildPodiumCard(participants[0], 1, const Color(0xffffd700)),
                    const SizedBox(width: 8),
                    // 3rd Place
                    if (participants.length >= 3)
                      _buildPodiumCard(participants[2], 3, const Color(0xffcd7f32)),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // All Participants List
              Container(
                decoration: BoxDecoration(
                  color: ThemeHelper.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeHelper.getBorderColor(context)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: participants.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: ThemeHelper.getBorderColor(context),
                  ),
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    final isCurrentUser = participant['id'] == widget.participantId;
                    final rank = participant['rank'];
                    final customValues = Map<String, dynamic>.from(
                      participant['custom_field_values'] ?? {}
                    );
                    final name = customValues['Name'] ?? 'Student';
                    final score = participant['score'] ?? 0;

                    return Container(
                      color: isCurrentUser
                          ? Colors.purple.withValues(alpha: 0.1)
                          : Colors.transparent,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Rank
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getRankColor(rank).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getRankDisplay(rank),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getRankColor(rank),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          
                          // Name and ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeHelper.getTextPrimary(context),
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'You',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (customValues['Student ID'] != null)
                                  Text(
                                    'ID: ${customValues['Student ID']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: ThemeHelper.getTextSecondary(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Score
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$score',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              Text(
                                '/${quizSession?.questions.length ?? 0}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: ThemeHelper.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Exit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.getPrimaryColor(context),
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumCard(Map<String, dynamic> participant, int rank, Color color) {
    final customValues = Map<String, dynamic>.from(
      participant['custom_field_values'] ?? {}
    );
    final name = customValues['Name'] ?? 'Student';
    final score = participant['score'] ?? 0;
    final isCurrentUser = participant['id'] == widget.participantId;

    return Expanded(
      child: Column(
        children: [
          // Medal/Trophy
          Container(
            width: rank == 1 ? 64 : 56,
            height: rank == 1 ? 64 : 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                rank == 1 ? '🏆' : rank == 2 ? '🥈' : '🥉',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Podium
          Container(
            height: rank == 1 ? 120 : rank == 2 ? 100 : 80,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? Colors.purple.withValues(alpha: 0.2)
                  : ThemeHelper.getCardColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(
                color: isCurrentUser ? Colors.purple : ThemeHelper.getBorderColor(context),
                width: isCurrentUser ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.getTextPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$score pts',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRankDisplay(int rank) {
    if (rank <= 3) {
      return rank == 1 ? '🏆' : rank == 2 ? '🥈' : '🥉';
    }
    return '$rank';
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xffffd700); // Gold
      case 2:
        return const Color(0xffc0c0c0); // Silver
      case 3:
        return const Color(0xffcd7f32); // Bronze
      default:
        return Colors.grey;
    }
  }
}
