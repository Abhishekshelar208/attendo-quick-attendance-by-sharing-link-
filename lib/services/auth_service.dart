import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google using Firebase native provider flow
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In...');
      print('📱 Platform: ${kIsWeb ? "Web" : "Mobile"}');

      UserCredential userCredential;

      if (kIsWeb) {
        print('🌍 Using web Google sign-in');
        // Web platform - use popup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        print('📱 Using mobile Google sign-in with native provider flow');
        // Mobile platform (Android/iOS) - use native provider flow
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'prompt': 'select_account',
        });
        
        print('🔑 Calling signInWithProvider...');
        userCredential = await _auth.signInWithProvider(googleProvider);
        print('✅ signInWithProvider completed');
      }

      User? user = userCredential.user;
      print('👤 User from credential: ${user?.email}');

      if (user != null) {
        print('✅ Firebase sign-in successful!');
        print('   User: ${user.displayName}');
        print('   Email: ${user.email}');
        print('   UID: ${user.uid}');
        print('   Photo: ${user.photoURL}');

        // Save user data to Realtime Database
        print('💾 Saving user data to database...');
        await _saveUserData(user);
        print('✅ User data saved');

        // Verify current user is set
        final currentUser = _auth.currentUser;
        print('👤 Current user after sign-in: ${currentUser?.email}');

        return userCredential;
      } else {
        print('❌ Google sign-in returned null user');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code}');
      print('❌ Message: ${e.message}');
      print('❌ Details: ${e.toString()}');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ Error signing in with Google: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Save user data to database
  Future<void> _saveUserData(User user) async {
    try {
      final userData = {
        'uid': user.uid,
        'name': user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
      };

      await _dbRef.child('users/${user.uid}').set(userData);
      print('✅ User data saved to database');
    } catch (e) {
      print('❌ Error saving user data: $e');
    }
  }

  // Update last login
  Future<void> updateLastLogin() async {
    if (currentUser != null) {
      await _dbRef.child('users/${currentUser!.uid}/lastLogin').set(
        DateTime.now().toIso8601String(),
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('👋 Signing out...');
      await _auth.signOut();
      print('✅ Sign out successful');
    } catch (e) {
      print('❌ Error signing out: $e');
      rethrow;
    }
  }

  // Get user data from database
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final snapshot = await _dbRef.child('users/$uid').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }
}
