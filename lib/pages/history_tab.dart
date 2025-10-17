import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendo/pages/StudentViewAttendanceScreen.dart';
import 'package:attendo/pages/EventViewParticipantsScreen.dart';
import 'package:attendo/pages/QuizReportScreen.dart';
import 'package:attendo/pages/FeedbackViewScreen.dart';
import 'package:attendo/pages/InstantDataViewScreen.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show Blob, AnchorElement, Url;

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
  String filter = 'all'; // all, attendance, events, quiz, feedback, instant_data
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  bool showStats = false;

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

      // Fetch ended feedback sessions
      final feedbackSnapshot = await _dbRef.child('feedback_sessions').get();
      if (feedbackSnapshot.exists) {
        final data = feedbackSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && 
              session['status'] == 'ended') {
            items.add({
              'id': key,
              'type': 'feedback',
              'title': session['name'] ?? 'Untitled Feedback',
              'session_type': session['type'] ?? 'Feedback',
              'date': '',
              'time': '',
              'year': '',
              'branch': '',
              'division': '',
              'count': (session['responses'] as Map?)?.length ?? 0,
              'created_at': session['created_at'] ?? '',
            });
          }
        });
      }

      // Fetch ended instant data collection sessions
      final instantDataSnapshot = await _dbRef.child('instant_data_collection').get();
      if (instantDataSnapshot.exists) {
        final data = instantDataSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && 
              session['status'] == 'ended') {
            items.add({
              'id': key,
              'type': 'instant_data',
              'title': session['title'] ?? 'Untitled Data Collection',
              'description': session['description'] ?? '',
              'date': '',
              'time': '',
              'year': '',
              'branch': '',
              'division': '',
              'count': (session['responses'] as Map?)?.length ?? 0,
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
    var items = historyItems;

    // Apply type filter
    if (filter != 'all') {
      items = items.where((item) => item['type'] == filter).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item['title'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // Apply date range filter
    if (filterStartDate != null || filterEndDate != null) {
      items = items.where((item) {
        final createdAt = DateTime.tryParse(item['created_at'] ?? '');
        if (createdAt == null) return false;
        
        if (filterStartDate != null && createdAt.isBefore(filterStartDate!)) {
          return false;
        }
        if (filterEndDate != null && createdAt.isAfter(filterEndDate!.add(const Duration(days: 1)))) {
          return false;
        }
        return true;
      }).toList();
    }

    return items;
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
          IconButton(
            icon: Icon(showStats ? Icons.list_rounded : Icons.bar_chart_rounded),
            onPressed: () => setState(() => showStats = !showStats),
            tooltip: showStats ? 'Show List' : 'Show Statistics',
          ),
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
              PopupMenuItem(
                value: 'feedback',
                child: Row(
                  children: [
                    Icon(Icons.feedback_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Feedback/Q&A', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'instant_data',
                child: Row(
                  children: [
                    Icon(Icons.poll_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Data Collection', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.date_range_rounded),
                  title: Text('Date Filter', style: GoogleFonts.poppins()),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: _showDateRangePicker,
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.file_download_rounded),
                  title: Text('Export CSV', style: GoogleFonts.poppins()),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: _exportHistoryCSV,
              ),
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text('Refresh', style: GoogleFonts.poppins()),
                  contentPadding: EdgeInsets.zero,
                ),
                onTap: _loadHistory,
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search sessions...',
                  hintStyle: GoogleFonts.poppins(color: ThemeHelper.getTextTertiary(context)),
                  prefixIcon: Icon(Icons.search_rounded, color: ThemeHelper.getTextSecondary(context)),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: ThemeHelper.getCardColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeHelper.getBorderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeHelper.getPrimaryColor(context), width: 2),
                  ),
                ),
              ),
            ),
            
            // Content
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getPrimaryColor(context),
                      ),
                    )
                  : showStats
                      ? _buildStatisticsView()
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
                                    'Your ended sessions will appear here',
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
                                  return Dismissible(
                                    key: Key(item['id']),
                                    background: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 32),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) => _confirmDelete(context, item),
                                    onDismissed: (direction) => _deleteSession(item),
                                    child: _buildHistoryCard(context, item),
                                  );
                                },
                              ),
                            ),
            ),
          ],
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
      case 'feedback':
        icon = Icons.feedback_rounded;
        color = item['session_type'] == 'Q&A' ? const Color(0xff3b82f6) : const Color(0xff059669);
        break;
      case 'instant_data':
        icon = Icons.poll_rounded;
        color = const Color(0xfff59e0b);
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
          } else if (type == 'feedback') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackViewScreen(
                  sessionId: item['id'],
                ),
              ),
            );
          } else if (type == 'instant_data') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstantDataViewScreen(
                  sessionId: item['id'],
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

  Future<bool?> _confirmDelete(BuildContext context, Map<String, dynamic> item) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Session?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Are you sure you want to delete "${item['title']}"? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteSession(Map<String, dynamic> item) async {
    try {
      final type = item['type'];
      String path = '';
      
      switch (type) {
        case 'attendance':
          path = 'attendance_sessions/${item['id']}';
          break;
        case 'event':
          path = 'event_sessions/${item['id']}';
          break;
        case 'quiz':
          path = 'quiz_sessions/${item['id']}';
          break;
        case 'feedback':
          path = 'feedback_sessions/${item['id']}';
          break;
        case 'instant_data':
          path = 'instant_data_collection/${item['id']}';
          break;
      }
      
      if (path.isNotEmpty) {
        await _dbRef.child(path).remove();
        setState(() {
          historyItems.removeWhere((i) => i['id'] == item['id']);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Session deleted', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting session', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDateRangePicker() async {
    Navigator.pop(context); // Close menu first
    
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: filterStartDate != null && filterEndDate != null
          ? DateTimeRange(start: filterStartDate!, end: filterEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeHelper.getPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        filterStartDate = picked.start;
        filterEndDate = picked.end;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Filtered: ${DateFormat('MMM d').format(picked.start)} - ${DateFormat('MMM d, yyyy').format(picked.end)}',
            style: GoogleFonts.poppins(),
          ),
          action: SnackBarAction(
            label: 'Clear',
            onPressed: () {
              setState(() {
                filterStartDate = null;
                filterEndDate = null;
              });
            },
          ),
        ),
      );
    }
  }

  void _exportHistoryCSV() async {
    Navigator.pop(context); // Close menu first
    
    if (filteredItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      
      // Header
      rows.add(['Type', 'Title', 'Date', 'Time', 'Year', 'Branch', 'Division', 'Count', 'Created At']);
      
      // Data
      for (var item in filteredItems) {
        rows.add([
          item['type'],
          item['title'],
          item['date'] ?? '-',
          item['time'] ?? '-',
          item['year'] ?? '-',
          item['branch'] ?? '-',
          item['division'] ?? '-',
          item['count'],
          item['created_at'],
        ]);
      }
      
      String csv = const ListToCsvConverter().convert(rows);
      final fileName = 'history_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      
      if (kIsWeb) {
        // Web: Download CSV
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV downloaded successfully!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mobile/Desktop: Save and share
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(csv);
        
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Session History Export',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully!', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error exporting CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatisticsView() {
    final stats = _calculateStatistics();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics Overview',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 24),
          
          // Total Sessions Card
          _buildStatCard(
            'Total Sessions',
            '${stats['total']}',
            Icons.history_rounded,
            ThemeHelper.getPrimaryColor(context),
          ),
          const SizedBox(height: 16),
          
          // Breakdown by Type
          Text(
            'By Type',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('Attendance', '${stats['attendance']}', Icons.school_rounded, ThemeHelper.getPrimaryColor(context), isSmall: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Events', '${stats['event']}', Icons.event_rounded, ThemeHelper.getSecondaryColor(context), isSmall: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Quizzes', '${stats['quiz']}', Icons.quiz_rounded, Colors.deepPurple, isSmall: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Feedback', '${stats['feedback']}', Icons.feedback_rounded, const Color(0xff3b82f6), isSmall: true)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard('Data Collection', '${stats['instant_data']}', Icons.poll_rounded, const Color(0xfff59e0b), isSmall: true),
          
          const SizedBox(height: 24),
          Text(
            'Engagement',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Responses/Participants',
            '${stats['total_count']}',
            Icons.people_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isSmall = false}) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeHelper.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isSmall ? 20 : 28),
          ),
          SizedBox(width: isSmall ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 12 : 14,
                    color: ThemeHelper.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: isSmall ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStatistics() {
    int total = historyItems.length;
    int attendance = historyItems.where((i) => i['type'] == 'attendance').length;
    int event = historyItems.where((i) => i['type'] == 'event').length;
    int quiz = historyItems.where((i) => i['type'] == 'quiz').length;
    int feedback = historyItems.where((i) => i['type'] == 'feedback').length;
    int instantData = historyItems.where((i) => i['type'] == 'instant_data').length;
    int totalCount = historyItems.fold(0, (sum, item) => sum + (item['count'] as int));
    
    return {
      'total': total,
      'attendance': attendance,
      'event': event,
      'quiz': quiz,
      'feedback': feedback,
      'instant_data': instantData,
      'total_count': totalCount,
    };
  }
}
