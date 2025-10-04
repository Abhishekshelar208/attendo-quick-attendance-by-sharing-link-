
// for a quick attendance

import 'package:attendo/pages/StudentAttendanceScreen.dart';
import 'package:attendo/pages/home_screen_with_nav.dart';
import 'package:attendo/pages/intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    //enable following option while deploying on web app.
    //    options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuickPro',
      debugShowCheckedModeBanner: false,
      // Light Theme (Minix-inspired)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xfff8f9fa),
        primaryColor: const Color(0xff2563eb), // Modern blue
        colorScheme: const ColorScheme.light(
          primary: Color(0xff2563eb),
          secondary: Color(0xff059669), // Green for success
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xff1f2937),
          error: Color(0xffef4444),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfff8f9fa),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xff1f2937)),
          titleTextStyle: TextStyle(
            color: Color(0xff2563eb),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff2563eb),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffe5e7eb)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xffe5e7eb)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff2563eb), width: 2),
          ),
        ),
      ),
      // Dark Theme (Minix-inspired)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0f172a),
        primaryColor: const Color(0xff3b82f6), // Brighter blue for dark mode
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff3b82f6),
          secondary: Color(0xff10b981), // Brighter green for dark mode
          surface: Color(0xff1e293b),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xfff1f5f9),
          error: Color(0xfff87171),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff0f172a),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xfff1f5f9)),
          titleTextStyle: TextStyle(
            color: Color(0xff3b82f6),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff3b82f6),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xff1e293b),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff1e293b),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff475569)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff475569)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff3b82f6), width: 2),
          ),
        ),
      ),
      // Automatically switch based on system theme
      themeMode: ThemeMode.system,
      home: const SplashChecker(),
      onGenerateRoute: (settings) {
        Uri uri = Uri.parse(settings.name ?? '');
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'session') {
          String sessionId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => StudentAttendanceScreen(sessionId: sessionId),
          );
        }
        return null;
      },
    );
  }
}

class SplashChecker extends StatefulWidget {
  const SplashChecker({super.key});

  @override
  State<SplashChecker> createState() => _SplashCheckerState();
}

class _SplashCheckerState extends State<SplashChecker> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool('intro_seen') ?? false;

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              hasSeenIntro ? const HomeScreenWithNav() : const IntroScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'QuickPro',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
