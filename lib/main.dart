
// for a quick attendance

import 'package:attendo/pages/ShareFeedbackScreen.dart';
import 'package:attendo/pages/StudentAttendanceScreen.dart';
import 'package:attendo/pages/StudentEventCheckInScreen.dart';
import 'package:attendo/pages/StudentFeedbackScreen.dart';
import 'package:attendo/pages/StudentQuizEntryScreen.dart';
import 'package:attendo/pages/home_screen_with_nav.dart';
import 'package:attendo/pages/intro_screen.dart';
import 'package:attendo/pages/LoginScreen.dart';
import 'package:attendo/services/auth_service.dart';
import 'package:attendo/pages/ShareInstantDataScreen.dart';
import 'package:attendo/pages/StudentInstantDataScreen.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase only if not already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    // Firebase already initialized (happens on Android sometimes)
    if (e.toString().contains('duplicate-app')) {
      print('ℹ️ Firebase already initialized');
    } else {
      print('❌ Firebase initialization error: $e');
      rethrow;
    }
  }
  
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
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashChecker(),
      },
      onGenerateRoute: (settings) {
        print('🔍 Navigation to: ${settings.name}');
        
        Uri uri = Uri.parse(settings.name ?? '');
        
        // Check for session route (classroom attendance)
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'session') {
          String sessionId = uri.pathSegments[1];
          print('📱 Opening session: $sessionId');
          return MaterialPageRoute(
            builder: (context) => StudentAttendanceScreen(sessionId: sessionId),
          );
        }
        
        // Check for event route
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'event') {
          String sessionId = uri.pathSegments[1];
          print('🎉 Opening event: $sessionId');
          return MaterialPageRoute(
            builder: (context) => StudentEventCheckInScreen(sessionId: sessionId),
          );
        }
        
        // Check for quiz route
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'quiz') {
          String quizId = uri.pathSegments[1];
          print('🎯 Opening quiz: $quizId');
          return MaterialPageRoute(
            builder: (context) => StudentQuizEntryScreen(quizId: quizId),
          );
        }
        
        // Check for instant data collection route
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'instant-data') {
          String sessionId = uri.pathSegments[1];
          print('📊 Opening instant data collection: $sessionId');
          return MaterialPageRoute(
            builder: (context) => StudentInstantDataScreen(sessionId: sessionId),
          );
        }
        
        // Instant Data Collection - Feature disabled (coming soon)
        // Check for instant data collection route
        // if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'instant-data') {
        //   String sessionId = uri.pathSegments[1];
        //   print('📊 Opening instant data collection: $sessionId');
        //   return MaterialPageRoute(
        //     builder: (context) => StudentInstantDataCollectionScreen(sessionId: sessionId),
        //   );
        // }
        // 
        // // Check for instant data collection share route (for teachers)
        // if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'instant-data-collection' && uri.pathSegments[1] == 'share') {
        //   if (settings.arguments != null && settings.arguments is String) {
        //     String sessionId = settings.arguments as String;
        //     print('📤 Opening instant data collection share: $sessionId');
        //     return MaterialPageRoute(
        //       builder: (context) => ShareInstantDataCollectionScreen(sessionId: sessionId),
        //     );
        //   }
        // }
        
        // Check for feedback session route (students)
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'feedback') {
          String sessionId = uri.pathSegments[1];
          print('💬 Opening feedback session: $sessionId');
          return MaterialPageRoute(
            builder: (context) => StudentFeedbackScreen(sessionId: sessionId),
          );
        }
        
        // Check for feedback share route (teachers)
        if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'feedback-share') {
          if (settings.arguments != null && settings.arguments is String) {
            String sessionId = settings.arguments as String;
            print('📤 Opening feedback share: $sessionId');
            return MaterialPageRoute(
              builder: (context) => ShareFeedbackScreen(sessionId: sessionId),
            );
          }
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
  final AuthService _authService = AuthService();
  bool _hasNavigated = false;
  
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
    
    // Listen for auth state changes
    _authService.authStateChanges.listen((User? user) {
      if (user != null && !_hasNavigated) {
        print('✅ Auth state changed: User signed in - ${user.email}');
        // User just signed in, ensure we're on the home screen
        _navigateToHome();
      }
    });
  }
  
  Future<void> _navigateToHome() async {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen', true);
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreenWithNav()),
        (route) => false,
      );
    }
  }

  Future<void> _checkFirstLaunch() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // On web, check if URL contains a session route
    if (kIsWeb) {
      final currentUrl = Uri.base.toString();
      print('🌍 Initial URL: $currentUrl');
      
      // Check for session in hash fragment (classroom attendance)
      if (currentUrl.contains('#/session/')) {
        final hashPart = Uri.base.fragment;
        print('🔗 Hash fragment: $hashPart');
        
        // Extract session ID from #/session/XXXXX
        final match = RegExp(r'#/session/([^/]+)').firstMatch(currentUrl);
        if (match != null) {
          final sessionId = match.group(1);
          print('✅ Found session ID: $sessionId');
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentAttendanceScreen(sessionId: sessionId!),
              ),
            );
            return;
          }
        }
      }
      
      // Check for event in hash fragment
      if (currentUrl.contains('#/event/')) {
        final hashPart = Uri.base.fragment;
        print('🔗 Hash fragment: $hashPart');
        
        // Extract event ID from #/event/XXXXX
        final match = RegExp(r'#/event/([^/]+)').firstMatch(currentUrl);
        if (match != null) {
          final eventId = match.group(1);
          print('✅ Found event ID: $eventId');
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentEventCheckInScreen(sessionId: eventId!),
              ),
            );
            return;
          }
        }
      }
      
      // Check for quiz in hash fragment
      if (currentUrl.contains('#/quiz/')) {
        final hashPart = Uri.base.fragment;
        print('🔗 Hash fragment: $hashPart');
        
        // Extract quiz ID from #/quiz/XXXXX
        final match = RegExp(r'#/quiz/([^/]+)').firstMatch(currentUrl);
        if (match != null) {
          final quizId = match.group(1);
          print('✅ Found quiz ID: $quizId');
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentQuizEntryScreen(quizId: quizId!),
              ),
            );
            return;
          }
        }
      }
      
      // Check for feedback session in hash fragment
      if (currentUrl.contains('#/feedback/')) {
        final hashPart = Uri.base.fragment;
        print('🔗 Hash fragment: $hashPart');
        
        // Extract feedback session ID from #/feedback/XXXXX
        final match = RegExp(r'#/feedback/([^/]+)').firstMatch(currentUrl);
        if (match != null) {
          final sessionId = match.group(1);
          print('✅ Found feedback session ID: $sessionId');
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentFeedbackScreen(sessionId: sessionId!),
              ),
            );
            return;
          }
        }
      }
      
      // Check for instant data collection in hash fragment
      if (currentUrl.contains('#/instant-data/')) {
        final hashPart = Uri.base.fragment;
        print('🔗 Hash fragment: $hashPart');
        
        // Extract session ID from #/instant-data/XXXXX
        final match = RegExp(r'#/instant-data/([^/]+)').firstMatch(currentUrl);
        if (match != null) {
          final sessionId = match.group(1);
          print('✅ Found instant data session ID: $sessionId');
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => StudentInstantDataScreen(sessionId: sessionId!),
              ),
            );
            return;
          }
        }
      }
      
    }
    
    // Default flow: check auth status
    final user = _authService.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final hasSeenIntro = prefs.getBool('intro_seen') ?? false;
    
    if (user != null) {
      // User is logged in
      print('✅ User authenticated: ${user.email}');
      
      if (hasSeenIntro) {
        // User has seen intro, go directly to home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreenWithNav()),
          );
        }
      } else {
        // User is authenticated but hasn't seen intro, show intro (they can skip it)
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const IntroScreen()),
          );
        }
      }
    } else {
      // User not logged in
      print('⚠️ User not authenticated');
      
      if (hasSeenIntro) {
        // User has seen intro before but logged out, show login screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        // First time user, show intro screen with sign-in on slide 3
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const IntroScreen()),
          );
        }
      }
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
