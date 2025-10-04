import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'StudentViewAttendanceScreen.dart';

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
  String? year;
  String? branch;
  bool isEnded = false;
  List<String> markedStudents = [];

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
          year = data['year'];
          branch = data['branch'];
          isEnded = data['is_ended'] ?? false;
          
          // If ended, fetch the attendance list
          if (isEnded && data['students'] != null) {
            Map<dynamic, dynamic> studentsMap = data['students'] as Map<dynamic, dynamic>;
            List<String> students = studentsMap.values.map((e) => e['entry'].toString()).toList();
            
            // Sort in ascending order
            students.sort((a, b) {
              final aNum = int.tryParse(a);
              final bNum = int.tryParse(b);
              if (aNum != null && bNum != null) {
                return aNum.compareTo(bNum);
              }
              return a.compareTo(b);
            });
            
            markedStudents = students;
          }
        });
      }
    });
  }

  void submitAttendance() async {
    if (_inputController.text.isEmpty) return;

    String enteredValue = _inputController.text.trim();

    // Check if roll number already exists
    DatabaseReference dbRef = FirebaseDatabase.instance
        .ref()
        .child("attendance_sessions/${widget.sessionId}/students");
    
    DatabaseEvent event = await dbRef.once();
    
    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> studentsMap = event.snapshot.value as Map<dynamic, dynamic>;
      List<String> existingEntries = studentsMap.values.map((e) => e['entry'].toString()).toList();
      
      // Check for duplicate
      if (existingEntries.contains(enteredValue)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("This $inputType is already marked!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Add new attendance entry
    String studentId = dbRef.push().key!;
    await dbRef.child(studentId).set({'entry': enteredValue});

    // Navigate to StudentViewAttendanceScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => StudentViewAttendanceScreen(sessionId: widget.sessionId),
      ),
    );
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text("Mark Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.indigo,
          centerTitle: true,
        ),
        body: inputType == null
            ? Center(child: CircularProgressIndicator(color: Colors.indigo))
            : isEnded
            ? _buildEndedView()
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card with Session Details
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.indigo, Colors.indigo.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.school, color: Colors.white, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    lectureName ?? "Loading...",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (year != null && branch != null) ...[
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "$year - $branch",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 40),
                      
                      // Attendance Form Card
                      Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Mark Your Presence",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Enter your details to mark attendance",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 24),
                            
                            // Input Field
                            TextField(
                              controller: _inputController,
                              decoration: InputDecoration(
                                labelText: inputType,
                                hintText: "Enter your $inputType",
                                prefixIcon: Icon(
                                  inputType == "Roll Number" ? Icons.tag : Icons.person,
                                  color: Colors.indigo,
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.indigo, width: 2),
                                ),
                                labelStyle: TextStyle(color: Colors.grey[700]),
                              ),
                              keyboardType: inputType == "Roll Number"
                                  ? TextInputType.number
                                  : TextInputType.text,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 28),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: submitAttendance,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: Colors.indigo.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      "Submit Attendance",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Info Box
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Please ensure your $inputType is correct before submitting.",
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEndedView() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card with Session Details
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Colors.orange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.block, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Attendance Ended",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    "This attendance session has been closed by the teacher.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            
            // Attendance Details Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attendance Details",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (lectureName != null) ...[
                    _buildDetailRow(Icons.book, "Lecture", lectureName!),
                    SizedBox(height: 12),
                  ],
                  if (year != null && branch != null) ...[
                    _buildDetailRow(Icons.school, "Class", "$year - $branch"),
                    SizedBox(height: 12),
                  ],
                  _buildDetailRow(Icons.people, "Total Present", "${markedStudents.length}"),
                ],
              ),
            ),
            SizedBox(height: 30),
            
            // Present Students List
            Text(
              "Present Students",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: markedStudents.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "No students marked attendance",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: markedStudents.map((rollNo) {
                        return CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.green,
                          child: Text(
                            rollNo,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo, size: 20),
        SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
