
// for a quick attendance

import 'package:attendo/pages/HomeScreenForQuickAttendnace.dart';
import 'package:attendo/pages/StudentAttendanceScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart'; // Import your screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    //enable following option while deploying on web app.
    //    options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Final Attendo',
      onGenerateRoute: (settings) {
        Uri uri = Uri.parse(settings.name ?? '');
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'session') {
          String sessionId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => StudentAttendanceScreen(sessionId: sessionId),
          );
        }
        return MaterialPageRoute(builder: (context) => HomeScreenForQuickAttendnace()); // Default screen
      },
    );
  }
}
