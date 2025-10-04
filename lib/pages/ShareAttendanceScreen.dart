import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';

class ShareAttendanceScreen extends StatefulWidget {
  final String sessionId;

  ShareAttendanceScreen({required this.sessionId});

  @override
  _ShareAttendanceScreenState createState() => _ShareAttendanceScreenState();
}

class _ShareAttendanceScreenState extends State<ShareAttendanceScreen> {
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref();
  List<String> markedStudents = [];
  String? lectureName;
  String? year;
  String? branch;
  bool isEnded = false;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
    _listenForAttendanceUpdates();
  }

  // Fetch session details
  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = _attendanceRef.child("attendance_sessions/${widget.sessionId}");
    sessionRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['lecture_name'];
          year = data['year'];
          branch = data['branch'];
          isEnded = data['is_ended'] ?? false;
        });
      }
    });
  }

  // Listen for live attendance updates
  void _listenForAttendanceUpdates() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/students").onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> updatedStudents = studentsMap.values.map((e) => e['entry'].toString()).toList();

        // Sort in ascending order (numeric if possible, otherwise alphabetic)
        updatedStudents.sort((a, b) {
          final aNum = int.tryParse(a);
          final bNum = int.tryParse(b);
          if (aNum != null && bNum != null) {
            return aNum.compareTo(bNum);
          }
          return a.compareTo(b);
        });

        setState(() {
          markedStudents = updatedStudents;
        });
      }
    });
  }

  void shareAttendanceLink() {
    String link = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    String message = "Join the attendance session:\n";
    if (lectureName != null) message += "Lecture: $lectureName\n";
    if (year != null && branch != null) message += "Year: $year | Branch: $branch\n";
    message += "Link: $link";
    Share.share(message, subject: "QuickAttendance Session");
  }

  void endAttendance() async {
    await _attendanceRef.child("attendance_sessions/${widget.sessionId}").update({
      'is_ended': true,
      'ended_at': DateTime.now().toIso8601String(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Attendance session has been ended"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void exportAttendance() {
    DateTime now = DateTime.now();
    String formattedDate = "${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year}";
    String formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    String report = "📅 Attendance Report\n";
    if (lectureName != null) report += "📚 Subject: $lectureName\n";
    report += "🗓 Date: $formattedDate\n";
    report += "🕐 Time: $formattedTime\n";
    if (year != null) report += "🧑 Year: $year\n";
    if (branch != null) report += "💼 Branch: $branch\n";
    report += "\n✅ Present Roll Numbers:\n";
    report += "[${markedStudents.join(', ')}]\n";
    report += "\nTotal Present: ${markedStudents.length}\n";
    report += "\n🔗 Session Link (Proof):\n";
    report += "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    
    Share.share(report, subject: "Attendance Report - $lectureName");
  }
  
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Share Attendance")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (lectureName != null) ...[
              Text(
                "Lecture: $lectureName",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
            ],
            if (year != null && branch != null) ...[
              Text(
                "Year: $year | Branch: $branch",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
            ],
            if (!isEnded) ...[
              Text("Share this link with students:"),
              SelectableText("https://attendo-312ea.web.app/#/session/${widget.sessionId}"),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: shareAttendanceLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text("Share Link", style: TextStyle(fontSize: 16)),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: endAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text("End Attendance", style: TextStyle(fontSize: 16)),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, color: Colors.orange[900]),
                    SizedBox(width: 10),
                    Text(
                      "Attendance Session Ended",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: exportAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text("Export Attendance", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
            SizedBox(height: 30),
            Text("Live Attendance:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: markedStudents.isEmpty
                  ? Text("No students have marked attendance yet.")
                  : Wrap(
                spacing: 10,
                runSpacing: 10,
                children: markedStudents.map((rollNo) {
                  return CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green,
                    child: Text(
                      rollNo,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
