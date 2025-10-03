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

  @override
  void initState() {
    super.initState();
    _listenForAttendanceUpdates();
  }

  // Listen for live attendance updates
  void _listenForAttendanceUpdates() {
    _attendanceRef.child("attendance_sessions/${widget.sessionId}/students").onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
        List<String> updatedStudents = studentsMap.values.map((e) => e['entry'].toString()).toList();

        setState(() {
          markedStudents = updatedStudents;
        });
      }
    });
  }

  void shareAttendanceLink() {
    String link = "https://attendo-312ea.web.app/#/session/${widget.sessionId}";
    Share.share("Join the attendance session: $link", subject: "QuickAttendance Session");
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
            Text("Share this link with students:"),
            SelectableText("https://attendo-312ea.web.app/#/session/${widget.sessionId}"),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: shareAttendanceLink,
              child: Text("Share Link"),
            ),
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
