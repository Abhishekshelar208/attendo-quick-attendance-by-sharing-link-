import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:attendo/services/quiz_pdf_generator.dart';
import 'dart:html' as html show Blob, AnchorElement, Url;

class QuizReportScreen extends StatefulWidget {
  final String quizId;

  const QuizReportScreen({Key? key, required this.quizId}) : super(key: key);

  @override
  _QuizReportScreenState createState() => _QuizReportScreenState();
}

class _QuizReportScreenState extends State<QuizReportScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  Map<String, dynamic>? quizData;
  Map<String, dynamic> participants = {};
  bool isLoading = true;
  bool isExportingCSV = false;
  bool isExportingPDF = false;

  @override
  void initState() {
    super.initState();
    _loadQuizReport();
  }

  Future<void> _loadQuizReport() async {
    try {
      final snapshot = await _database.child('quiz_sessions/${widget.quizId}').get();
      if (snapshot.exists) {
        setState(() {
          quizData = Map<String, dynamic>.from(snapshot.value as Map);
          participants = quizData?['participants'] != null
              ? Map<String, dynamic>.from(quizData!['participants'] as Map)
              : {};
          isLoading = false;
        });
      }
    } catch (e) {
      _showError('Error loading report: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _exportToPDF() async {
    setState(() => isExportingPDF = true);

    try {
      final file = await QuizPdfGenerator.generateQuizReport(
        quizData: quizData!,
        participants: participants,
      );

      setState(() => isExportingPDF = false);

      if (kIsWeb) {
        // Web: File is already downloaded via browser
        _showSuccess('PDF downloaded successfully!');
      } else {
        // Mobile/Desktop: Show options dialog
        if (!mounted) return;
        _showPdfOptionsDialog(file);
      }
    } catch (e) {
      _showError('Error generating PDF: $e');
      setState(() => isExportingPDF = false);
    }
  }

  Future<void> _showPdfOptionsDialog(File file) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generated'),
        content: const Text('Choose an action for the generated PDF report:'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Open PDF using system default viewer
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Quiz Report - ${quizData?['quiz_name']}',
                );
              } catch (e) {
                _showError('Error opening PDF: $e');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Share PDF
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Quiz Report - ${quizData?['quiz_name']}',
                );
                _showSuccess('PDF shared successfully!');
              } catch (e) {
                _showError('Error sharing PDF: $e');
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSuccess('PDF saved to: ${file.path}');
            },
            icon: const Icon(Icons.download_done),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    setState(() => isExportingCSV = true);

    try {
      List<List<dynamic>> rows = [];

      // Header row
      List<String> header = ['Rank', 'Name'];
      
      // Add custom field headers
      if (participants.isNotEmpty) {
        final firstParticipant = participants.values.first;
        final customFields = firstParticipant['custom_field_values'] as Map?;
        if (customFields != null) {
          customFields.keys.where((k) => k != 'Name').forEach((key) {
            header.add(key);
          });
        }
      }
      
      header.addAll(['Score', 'Total Questions', 'Percentage', 'Status']);
      rows.add(header);

      // Data rows
      final sortedParticipants = participants.entries.toList()
        ..sort((a, b) {
          final scoreA = a.value['score'] ?? 0;
          final scoreB = b.value['score'] ?? 0;
          return scoreB.compareTo(scoreA);
        });

      final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;

      for (var i = 0; i < sortedParticipants.length; i++) {
        final participant = sortedParticipants[i].value;
        final customFields = participant['custom_field_values'] as Map?;
        final answers = participant['answers'] as List?;
        final score = participant['score'] ?? 0;
        final answeredCount = answers?.length ?? 0;

        List<dynamic> row = [
          i + 1,
          customFields?['Name'] ?? 'Unknown',
        ];

        // Add custom field values
        if (customFields != null) {
          customFields.entries.where((e) => e.key != 'Name').forEach((entry) {
            row.add(entry.value);
          });
        }

        final percentage = totalQuestions > 0 ? ((score / totalQuestions) * 100).toStringAsFixed(1) : '0.0';
        final status = answeredCount == totalQuestions ? 'Completed' : 'Incomplete';

        row.addAll([score, totalQuestions, '$percentage%', status]);
        rows.add(row);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'quiz_report_${widget.quizId}_$timestamp.csv';

      if (kIsWeb) {
        // Web: Download CSV directly
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        _showSuccess('CSV downloaded successfully!');
      } else {
        // Mobile/Desktop: Save and show options
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csv);

        if (mounted) {
          _showCsvOptionsDialog(file);
        }
      }
    } catch (e) {
      _showError('Error exporting CSV: $e');
    } finally {
      setState(() => isExportingCSV = false);
    }
  }

  Future<void> _showCsvOptionsDialog(File file) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Generated'),
        content: const Text('Choose an action for the generated CSV report:'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Open CSV using system default viewer
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Quiz Report - ${quizData?['quiz_name']}',
                );
              } catch (e) {
                _showError('Error opening CSV: $e');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Share CSV
                await Share.shareXFiles(
                  [XFile(file.path)],
                  subject: 'Quiz Report - ${quizData?['quiz_name']}',
                );
                _showSuccess('CSV shared successfully!');
              } catch (e) {
                _showError('Error sharing CSV: $e');
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showSuccess('CSV saved to: ${file.path}');
            },
            icon: const Icon(Icons.download_done),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  double _getAverageScore() {
    if (participants.isEmpty) return 0.0;
    
    final totalScore = participants.values.fold<int>(0, (sum, p) {
      final score = (p['score'] as int?) ?? 0;
      return sum + score;
    });
    return totalScore / participants.length;
  }

  int _getHighestScore() {
    if (participants.isEmpty) return 0;
    return participants.values.fold<int>(0, (max, p) {
      final score = (p['score'] as int?) ?? 0;
      return score > max ? score : max;
    });
  }

  int _getLowestScore() {
    if (participants.isEmpty) return 0;
    int minScore = 999999;
    for (var p in participants.values) {
      final score = (p['score'] as int?) ?? 999999;
      if (score < minScore) minScore = score;
    }
    return minScore == 999999 ? 0 : minScore;
  }

  Map<int, int> _getScoreDistribution() {
    final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;
    Map<int, int> distribution = {};
    
    for (int i = 0; i <= totalQuestions; i++) {
      distribution[i] = 0;
    }

    for (var participant in participants.values) {
      final score = participant['score'] ?? 0;
      distribution[score] = (distribution[score] ?? 0) + 1;
    }

    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Report'),
          backgroundColor: const Color(0xff8b5cf6),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalQuestions = (quizData?['questions'] as List?)?.length ?? 0;
    final totalParticipants = participants.length;
    final averageScore = _getAverageScore();
    final highestScore = _getHighestScore();
    final lowestScore = _getLowestScore();
    final averagePercentage = totalQuestions > 0 ? (averageScore / totalQuestions) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Report'),
        backgroundColor: const Color(0xff8b5cf6),
        actions: [
          if (!isExportingPDF)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export as PDF',
              onPressed: _exportToPDF,
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (!isExportingCSV)
            IconButton(
              icon: const Icon(Icons.table_chart),
              tooltip: 'Export as CSV',
              onPressed: _exportToCSV,
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuizReport,
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
                      Text(
                        quizData?['quiz_name'] ?? 'Quiz Report',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 20),

              // Statistics Section
              const Text(
                'Overall Statistics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard('Total Participants', totalParticipants.toString(), Icons.people, Colors.blue),
                  _buildStatCard('Total Questions', totalQuestions.toString(), Icons.quiz, const Color(0xff8b5cf6)),
                  _buildStatCard('Average Score', averageScore.toStringAsFixed(1), Icons.bar_chart, Colors.orange),
                  _buildStatCard('Average %', '${averagePercentage.toStringAsFixed(1)}%', Icons.percent, Colors.green),
                  _buildStatCard('Highest Score', '$highestScore/$totalQuestions', Icons.arrow_upward, Colors.green),
                  _buildStatCard('Lowest Score', '$lowestScore/$totalQuestions', Icons.arrow_downward, Colors.red),
                ],
              ),
              const SizedBox(height: 24),

              // Leaderboard Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Leaderboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalParticipants students',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (totalParticipants == 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No participants yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                _buildLeaderboard(totalQuestions),
            ],
          ),
        ),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(int totalQuestions) {
    final sortedParticipants = participants.entries.toList()
      ..sort((a, b) {
        final scoreA = a.value['score'] ?? 0;
        final scoreB = b.value['score'] ?? 0;
        return scoreB.compareTo(scoreA);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedParticipants.length,
      itemBuilder: (context, index) {
        final participantId = sortedParticipants[index].key;
        final participant = sortedParticipants[index].value;
        final rank = index + 1;
        return _buildLeaderboardCard(participantId, participant, rank, totalQuestions);
      },
    );
  }

  Widget _buildLeaderboardCard(String participantId, dynamic participant, int rank, int totalQuestions) {
    final customFieldValues = participant['custom_field_values'] as Map?;
    final answers = participant['answers'] as List?;
    final score = participant['score'] ?? 0;
    final percentage = totalQuestions > 0 ? ((score / totalQuestions) * 100).toStringAsFixed(1) : '0.0';

    Color rankColor = Colors.grey;
    IconData? medalIcon;
    
    if (rank == 1) {
      rankColor = Colors.amber;
      medalIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
      medalIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown;
      medalIcon = Icons.emoji_events;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: rank <= 3 ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: rank <= 3
            ? BorderSide(color: rankColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: rankColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: medalIcon != null
                    ? Icon(medalIcon, color: rankColor, size: 28)
                    : Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: rankColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Participant Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customFieldValues?['Name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (customFieldValues != null)
                    ...customFieldValues.entries
                        .where((e) => e.key != 'Name')
                        .map((e) => Text(
                              '${e.key}: ${e.value}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ))
                        .take(2),
                ],
              ),
            ),
            
            // Score Display
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score/$totalQuestions',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff8b5cf6),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
