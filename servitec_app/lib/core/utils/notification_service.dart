import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(initSettings);

      // Get FCM token
      final token = await _messaging.getToken();
      if (token != null) {
        // Token will be saved when user logs in
        _currentToken = token;
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _currentToken = token;
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    }
  }

  String? _currentToken;
  String? get currentToken => _currentToken;

  // Save FCM token to user document
  Future<void> saveTokenToUser(String userId) async {
    if (_currentToken == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'fcmToken': _currentToken});
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'ServiTec',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'servitec_channel',
          'ServiTec Notifications',
          channelDescription: 'Notificaciones de servicios',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Handle background notification tap
  void _handleMessageTap(RemoteMessage message) {
    // Navigation will be handled by the app
  }

  // Send notification to a specific user (via their FCM token)
  // In production, this should be done via Cloud Functions
  // This is a placeholder for the notification flow
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    // In MVP, we store the notification in Firestore
    // A Cloud Function would then send the actual push notification
    // For now, we create a notification document
    await FirebaseFirestore.instance.collection('notificaciones').add({
      'userId': userId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
