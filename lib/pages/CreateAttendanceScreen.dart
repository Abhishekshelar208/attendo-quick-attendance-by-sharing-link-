import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'ShareAttendanceScreen.dart';


class CreateAttendanceScreen extends StatefulWidget {
  @override
  _CreateAttendanceScreenState createState() => _CreateAttendanceScreenState();
}

class _CreateAttendanceScreenState extends State<CreateAttendanceScreen> {
  final TextEditingController _lectureNameController = TextEditingController();
  String selectedType = "Roll Number";

  void createAttendanceSession() async {
    DatabaseReference dbRef = FirebaseDatabase.instance.ref().child("attendance_sessions");
    String sessionId = dbRef.push().key!;

    await dbRef.child(sessionId).set({
      'lecture_name': _lectureNameController.text,
      'date': DateTime.now().toIso8601String(),
      'type': selectedType,
      'students': {}
    });

    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ShareAttendanceScreen(sessionId: sessionId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Attendance")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _lectureNameController,
              decoration: InputDecoration(labelText: "Lecture Name"),
            ),
            DropdownButton<String>(
              value: selectedType,
              items: ["Roll Number", "Student Name"]
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => selectedType = value!),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: createAttendanceSession,
              child: Text("Create Attendance"),
            )
          ],
        ),
      ),
    );
  }
}
