import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ActivityType {
  eventCreated,
  eventEnded,
  attendanceStarted,
  attendanceEnded,
  eventCheckIn,
  attendanceMarked,
}

class ActivityService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log user activity
  Future<void> logActivity({
    required ActivityType type,
    required String title,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ Cannot log activity - user not authenticated');
        return;
      }

      final activityData = {
        'type': type.toString().split('.').last,
        'title': title,
        'description': description ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? 'User',
        'metadata': metadata ?? {},
      };

      // Save to user's activity history
      await _dbRef
          .child('users/${user.uid}/activities')
          .push()
          .set(activityData);

      print('✅ Activity logged: $title');
    } catch (e) {
      print('❌ Error logging activity: $e');
    }
  }

  // Get user activities
  Future<List<Map<String, dynamic>>> getUserActivities(String uid, {int limit = 50}) async {
    try {
      final snapshot = await _dbRef
          .child('users/$uid/activities')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (!snapshot.exists) {
        return [];
      }

      final activitiesMap = snapshot.value as Map;
      final activities = activitiesMap.entries.map((entry) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        data['id'] = entry.key;
        return data;
      }).toList();

      // Sort by timestamp descending (newest first)
      activities.sort((a, b) {
        final aTime = DateTime.parse(a['timestamp']);
        final bTime = DateTime.parse(b['timestamp']);
        return bTime.compareTo(aTime);
      });

      return activities;
    } catch (e) {
      print('❌ Error getting user activities: $e');
      return [];
    }
  }

  // Get activity stats
  Future<Map<String, int>> getActivityStats(String uid) async {
    try {
      final snapshot = await _dbRef
          .child('users/$uid/activities')
          .get();

      if (!snapshot.exists) {
        return {
          'eventCreated': 0,
          'eventEnded': 0,
          'attendanceStarted': 0,
          'attendanceEnded': 0,
          'eventCheckIn': 0,
          'attendanceMarked': 0,
        };
      }

      final activitiesMap = snapshot.value as Map;
      final stats = <String, int>{
        'eventCreated': 0,
        'eventEnded': 0,
        'attendanceStarted': 0,
        'attendanceEnded': 0,
        'eventCheckIn': 0,
        'attendanceMarked': 0,
      };

      for (var activity in activitiesMap.values) {
        final type = activity['type'] as String;
        if (stats.containsKey(type)) {
          stats[type] = (stats[type] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error getting activity stats: $e');
      return {
        'eventCreated': 0,
        'eventEnded': 0,
        'attendanceStarted': 0,
        'attendanceEnded': 0,
        'eventCheckIn': 0,
        'attendanceMarked': 0,
      };
    }
  }

  // Clear all activities (for testing)
  Future<void> clearActivities(String uid) async {
    try {
      await _dbRef.child('users/$uid/activities').remove();
      print('✅ Activities cleared');
    } catch (e) {
      print('❌ Error clearing activities: $e');
    }
  }
}
