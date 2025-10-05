import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class QuizPdfGenerator {
  static Future<File> generateQuizReport({
    required Map<String, dynamic> quizData,
    required Map<String, dynamic> participants,
  }) async {
    final pdf = pw.Document();

    // Sort participants by score
    final sortedParticipants = participants.entries.toList()
      ..sort((a, b) {
        final scoreA = (a.value['score'] as int?) ?? 0;
        final scoreB = (b.value['score'] as int?) ?? 0;
        return scoreB.compareTo(scoreA);
      });

    final totalQuestions = (quizData['questions'] as List?)?.length ?? 0;
    final totalParticipants = participants.length;

    // Calculate statistics
    final scores = sortedParticipants.map((e) => (e.value['score'] as int?) ?? 0).toList();
    final averageScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final highestScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
    final lowestScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b);

    // Get top 3 winners
    final top3 = sortedParticipants.take(3).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          _buildHeader(quizData),
          pw.SizedBox(height: 20),

          // Summary Statistics
          _buildStatistics(
            totalParticipants: totalParticipants,
            totalQuestions: totalQuestions,
            averageScore: averageScore,
            highestScore: highestScore,
            lowestScore: lowestScore,
          ),
          pw.SizedBox(height: 30),

          // Top 3 Winners
          _buildTop3Winners(top3, totalQuestions),
          pw.SizedBox(height: 30),

          // Complete Leaderboard
          _buildLeaderboard(sortedParticipants, totalQuestions),
          pw.SizedBox(height: 20),

          // Footer
          _buildFooter(),
        ],
      ),
    );

    // Save PDF
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'quiz_report_${quizData['quiz_name']}_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> quizData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [PdfColors.deepPurple, PdfColors.purple],
        ),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'QUIZ REPORT',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            quizData['quiz_name'] ?? 'Quiz',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '📅 ${quizData['date'] ?? ''}',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '🕐 ${quizData['time'] ?? ''}',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '🎓 ${quizData['year']} ${quizData['branch']}',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '📚 Division ${quizData['division']}',
                    style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatistics({
    required int totalParticipants,
    required int totalQuestions,
    required double averageScore,
    required int highestScore,
    required int lowestScore,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SUMMARY STATISTICS',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.deepPurple,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              'Total Participants',
              totalParticipants.toString(),
              PdfColors.blue,
            ),
            _buildStatCard(
              'Total Questions',
              totalQuestions.toString(),
              PdfColors.deepPurple,
            ),
            _buildStatCard(
              'Average Score',
              averageScore.toStringAsFixed(1),
              PdfColors.orange,
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              'Highest Score',
              '$highestScore/$totalQuestions',
              PdfColors.green,
            ),
            _buildStatCard(
              'Lowest Score',
              '$lowestScore/$totalQuestions',
              PdfColors.red,
            ),
            _buildStatCard(
              'Average %',
              totalQuestions > 0
                  ? '${((averageScore / totalQuestions) * 100).toStringAsFixed(1)}%'
                  : '0%',
              PdfColors.teal,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        decoration: pw.BoxDecoration(
          color: color.shade(0.1),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: color, width: 2),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTop3Winners(
    List<MapEntry<String, dynamic>> top3,
    int totalQuestions,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(
              colors: [PdfColors.amber, PdfColors.orange],
            ),
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '🏆 TOP 3 WINNERS 🏆',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: [
            // 2nd Place
            if (top3.length > 1)
              _buildWinnerCard(
                top3[1],
                2,
                totalQuestions,
                PdfColors.grey400,
                '🥈',
              ),
            // 1st Place
            if (top3.isNotEmpty)
              _buildWinnerCard(
                top3[0],
                1,
                totalQuestions,
                const PdfColor.fromInt(0xFFFFD700), // Gold
                '🥇',
              ),
            // 3rd Place
            if (top3.length > 2)
              _buildWinnerCard(
                top3[2],
                3,
                totalQuestions,
                const PdfColor.fromInt(0xFFCD7F32), // Bronze
                '🥉',
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildWinnerCard(
    MapEntry<String, dynamic> participant,
    int rank,
    int totalQuestions,
    PdfColor color,
    String medal,
  ) {
    final customFields = participant.value['custom_field_values'] as Map?;
    final name = customFields?['Name'] ?? 'Unknown';
    final score = (participant.value['score'] as int?) ?? 0;
    final percentage = totalQuestions > 0
        ? ((score / totalQuestions) * 100).toStringAsFixed(1)
        : '0.0';

    return pw.Container(
      width: 150,
      height: rank == 1 ? 180 : 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: color, width: 3),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            medal,
            style: const pw.TextStyle(fontSize: 40),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '#$rank',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            name,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '$score/$totalQuestions',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            '$percentage%',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLeaderboard(
    List<MapEntry<String, dynamic>> sortedParticipants,
    int totalQuestions,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'COMPLETE LEADERBOARD',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.deepPurple,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(50),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColors.deepPurple,
              ),
              children: [
                _buildTableCell('Rank', isHeader: true),
                _buildTableCell('Name', isHeader: true),
                _buildTableCell('Score', isHeader: true),
                _buildTableCell('Percentage', isHeader: true),
              ],
            ),
            // Data rows
            ...sortedParticipants.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final participant = entry.value.value;
              final customFields = participant['custom_field_values'] as Map?;
              final name = customFields?['Name'] ?? 'Unknown';
              final score = (participant['score'] as int?) ?? 0;
              final percentage = totalQuestions > 0
                  ? ((score / totalQuestions) * 100).toStringAsFixed(1)
                  : '0.0';

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: rank <= 3
                      ? (rank == 1
                          ? const PdfColor.fromInt(0xFFFFF3CD)
                          : rank == 2
                              ? const PdfColor.fromInt(0xFFE8E8E8)
                              : const PdfColor.fromInt(0xFFFFE4C4))
                      : (rank % 2 == 0 ? PdfColors.grey200 : PdfColors.white),
                ),
                children: [
                  _buildTableCell('#$rank'),
                  _buildTableCell(name),
                  _buildTableCell('$score/$totalQuestions'),
                  _buildTableCell('$percentage%'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Powered by QuickPro - Quiz Management System',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}
