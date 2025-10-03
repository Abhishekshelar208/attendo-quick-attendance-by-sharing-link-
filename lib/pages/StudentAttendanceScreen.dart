import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String sessionId;

  StudentAttendanceScreen({required this.sessionId});

  @override
  _StudentAttendanceScreenState createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final TextEditingController _inputController = TextEditingController();
  String? lectureName;
  String? inputType; // Will be either "Roll Number" or "Name"

  @override
  void initState() {
    super.initState();
    _fetchSessionDetails();
  }

  void _fetchSessionDetails() async {
    DatabaseReference sessionRef =
    FirebaseDatabase.instance.ref().child("attendance_sessions/${widget.sessionId}");

    sessionRef.once().then((DatabaseEvent event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          lectureName = data['lecture_name'];
          inputType = data['type']; // "Roll Number" or "Name"
        });
      }
    });
  }

  void submitAttendance() async {
    if (_inputController.text.isEmpty) return;

    DatabaseReference dbRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}/students");
    String studentId = dbRef.push().key!;

    await dbRef.child(studentId).set({'entry': _inputController.text});

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Attendance Marked!")));

    _inputController.clear(); // Clear input field after submission
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mark Attendance")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lectureName != null) ...[
              Text(
                "Lecture: $lectureName",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
            ],
            if (inputType != null) ...[
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  labelText: "Enter your $inputType",
                ),
                keyboardType: inputType == "Roll Number"
                    ? TextInputType.number
                    : TextInputType.text,
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: submitAttendance, child: Text("Submit")),
            ] else
              Center(child: CircularProgressIndicator()), // Show loading until data is fetched
          ],
        ),
      ),
    );
  }
}
