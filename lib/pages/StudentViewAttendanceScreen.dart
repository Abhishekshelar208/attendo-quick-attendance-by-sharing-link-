import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';

class StudentViewAttendanceScreen extends StatefulWidget {
  final String sessionId;

  StudentViewAttendanceScreen({required this.sessionId});

  @override
  _StudentViewAttendanceScreenState createState() => _StudentViewAttendanceScreenState();
}

class _StudentViewAttendanceScreenState extends State<StudentViewAttendanceScreen> {
  final DatabaseReference _attendanceRef = FirebaseDatabase.instance.ref();
  List<String> markedStudents = [];
  String? lectureName;
  String? year;
  String? branch;

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
    _listenForAttendanceUpdates();
  }

  // Fetch session details
  void _fetchSessionDetails() async {
    DatabaseReference sessionRef = _attendanceRef.child("attendance_sessions/${widget.sessionId}");
    sessionRef.once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['lecture_name'];
          year = data['year'];
          branch = data['branch'];
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Close the app/tab instead of going back
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Attendance Marked"),
          automaticallyImplyLeading: false, // Remove back button from AppBar
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
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
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Your attendance has been marked!",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[900]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              Text("Present Students:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
