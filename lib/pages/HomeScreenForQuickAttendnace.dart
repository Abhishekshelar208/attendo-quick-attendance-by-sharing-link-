import 'package:flutter/material.dart';

import 'CreateAttendanceScreen.dart';


class HomeScreenForQuickAttendnace extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(title: Text("Quick Attendance")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome to Quick Attendance",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateAttendanceScreen()),
                );
              },
              child: Text("Create Attendance"),
            ),
          ],
        ),
      ),
    );
  }
}
