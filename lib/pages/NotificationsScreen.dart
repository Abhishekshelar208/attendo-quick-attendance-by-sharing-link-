import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendo/utils/theme_helper.dart';
import 'package:attendo/utils/animation_helper.dart';
import 'package:attendo/widgets/common_widgets.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => isLoading = true);
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      List<Map<String, dynamic>> allNotifications = [];
      
      // Fetch notifications for ended sessions
      final sessionsSnapshot = await _dbRef.child('attendance_sessions').get();
      if (sessionsSnapshot.exists) {
        final data = sessionsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && session['is_ended'] == true) {
            final endedAt = session['ended_at'] ?? session['created_at'];
            if (endedAt != null) {
              allNotifications.add({
                'id': 'attendance_$key',
                'type': 'attendance_ended',
                'title': 'Attendance Session Ended',
                'message': '${session['subject']} session has ended with ${(session['students'] as Map?)?.length ?? 0} students present',
                'timestamp': endedAt,
                'read': session['notification_read'] ?? false,
                'icon': Icons.check_circle_rounded,
                'color': const Color(0xff2563eb),
                'sessionId': key,
              });
            }
          }
        });
      }

      // Fetch event notifications
      final eventsSnapshot = await _dbRef.child('event_sessions').get();
      if (eventsSnapshot.exists) {
        final data = eventsSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && session['status'] == 'ended') {
            allNotifications.add({
              'id': 'event_$key',
              'type': 'event_ended',
              'title': 'Event Concluded',
              'message': '${session['event_name']} ended with ${(session['participants'] as Map?)?.length ?? 0} participants',
              'timestamp': session['created_at'],
              'read': session['notification_read'] ?? false,
              'icon': Icons.celebration_rounded,
              'color': const Color(0xffec4899),
              'sessionId': key,
            });
          }
        });
      }

      // Fetch quiz notifications
      final quizSnapshot = await _dbRef.child('quiz_sessions').get();
      if (quizSnapshot.exists) {
        final data = quizSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && session['status'] == 'ended') {
            allNotifications.add({
              'id': 'quiz_$key',
              'type': 'quiz_ended',
              'title': 'Quiz Completed',
              'message': '${session['quiz_name']} finished with ${(session['participants'] as Map?)?.length ?? 0} participants',
              'timestamp': session['created_at'],
              'read': session['notification_read'] ?? false,
              'icon': Icons.quiz_rounded,
              'color': const Color(0xff8b5cf6),
              'sessionId': key,
            });
          }
        });
      }

      // Fetch feedback notifications
      final feedbackSnapshot = await _dbRef.child('feedback_sessions').get();
      if (feedbackSnapshot.exists) {
        final data = feedbackSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && session['status'] == 'ended') {
            allNotifications.add({
              'id': 'feedback_$key',
              'type': 'feedback_ended',
              'title': '${session['type']} Session Ended',
              'message': '${session['name']} received ${(session['responses'] as Map?)?.length ?? 0} responses',
              'timestamp': session['created_at'],
              'read': session['notification_read'] ?? false,
              'icon': Icons.feedback_rounded,
              'color': const Color(0xff059669),
              'sessionId': key,
            });
          }
        });
      }

      // Fetch instant data notifications
      final instantDataSnapshot = await _dbRef.child('instant_data_collection').get();
      if (instantDataSnapshot.exists) {
        final data = instantDataSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final session = Map<String, dynamic>.from(value as Map);
          if (session['creator_uid'] == currentUser.uid && session['status'] == 'ended') {
            allNotifications.add({
              'id': 'instant_data_$key',
              'type': 'instant_data_ended',
              'title': 'Data Collection Ended',
              'message': '${session['title']} collected ${(session['responses'] as Map?)?.length ?? 0} responses',
              'timestamp': session['created_at'],
              'read': session['notification_read'] ?? false,
              'icon': Icons.poll_rounded,
              'color': const Color(0xfff59e0b),
              'sessionId': key,
            });
          }
        });
      }

      // Sort by timestamp (newest first)
      allNotifications.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      // Count unread
      final unread = allNotifications.where((n) => n['read'] == false).length;

      setState(() {
        notifications = allNotifications;
        unreadCount = unread;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() => isLoading = false);
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime dt = DateTime.parse(timestamp);
      DateTime now = DateTime.now();
      Duration diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('MMM d, yyyy').format(dt);
      }
    } catch (e) {
      return timestamp;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final notification = notifications.firstWhere((n) => n['id'] == notificationId);
    final type = notification['type'] as String;
    final sessionId = notification['sessionId'];

    try {
      String path = '';
      if (type.contains('attendance')) {
        path = 'attendance_sessions/$sessionId';
      } else if (type.contains('event')) {
        path = 'event_sessions/$sessionId';
      } else if (type.contains('quiz')) {
        path = 'quiz_sessions/$sessionId';
      } else if (type.contains('feedback')) {
        path = 'feedback_sessions/$sessionId';
      } else if (type.contains('instant_data')) {
        path = 'instant_data_collection/$sessionId';
      }

      if (path.isNotEmpty) {
        await _dbRef.child(path).update({'notification_read': true});
        
        setState(() {
          notification['read'] = true;
          unreadCount = notifications.where((n) => n['read'] == false).length;
        });
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      for (var notification in notifications.where((n) => n['read'] == false)) {
        await _markAsRead(notification['id']);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All notifications marked as read', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Notifications?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will mark all notifications as read. You can still access your session history.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThemeHelper.getPrimaryColor(context)),
            child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _markAllAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            if (unreadCount > 0)
              Text(
                '$unreadCount unread',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: ThemeHelper.getTextSecondary(context),
                ),
              ),
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (context) => [
                if (unreadCount > 0)
                  PopupMenuItem(
                    child: ListTile(
                      leading: const Icon(Icons.done_all_rounded),
                      title: Text('Mark all as read', style: GoogleFonts.poppins()),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _markAllAsRead();
                    },
                  ),
                PopupMenuItem(
                  child: ListTile(
                    leading: const Icon(Icons.clear_all_rounded),
                    title: Text('Clear all', style: GoogleFonts.poppins()),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _clearAll();
                  },
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: ThemeHelper.getPrimaryColor(context),
                ),
              )
            : notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 80,
                          color: ThemeHelper.getTextTertiary(context),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Notifications',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeHelper.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You\'re all caught up!',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return SlideInWidget(
                          delay: Duration(milliseconds: 100 + (index * 50)),
                          child: _buildNotificationCard(notification),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] as bool;
    
    return Dismissible(
      key: Key(notification['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.done_rounded, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.done_rounded, color: Colors.white, size: 32),
      ),
      onDismissed: (direction) {
        _markAsRead(notification['id']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead 
              ? ThemeHelper.getCardColor(context)
              : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? ThemeHelper.getBorderColor(context)
                : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
            width: isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _markAsRead(notification['id']),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (notification['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      notification['icon'] as IconData,
                      color: notification['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'],
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.getTextPrimary(context),
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: ThemeHelper.getPrimaryColor(context),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification['message'],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: ThemeHelper.getTextSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTimestamp(notification['timestamp']),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: ThemeHelper.getTextTertiary(context),
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
      ),
    );
  }
}
