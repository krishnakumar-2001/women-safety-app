import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// ─── Background handler (must be top-level) ───────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.showFCMNotification(message);
}

// ─── NotificationService ──────────────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isCancelled = false;
  static bool get isCancelled => _isCancelled;

  // ── Channels ─────────────────────────────────────────────────────────────────
  static const AndroidNotificationChannel _sosChannel =
      AndroidNotificationChannel(
        'sos_channel',
        'SOS Alerts',
        description: 'High priority SOS countdown notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  static const AndroidNotificationChannel _fcmChannel =
      AndroidNotificationChannel(
        'fcm_channel',
        'Push Notifications',
        description: 'Firebase Cloud Messaging push notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

  // ── Initialise ────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // v21+: initialize() uses named parameter 'settings'
    await _notificationsPlugin.initialize(
      settings: const InitializationSettings(android: initAndroid),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'cancel_sos') {
          _isCancelled = true;
          // v21+: cancel() uses named parameter 'id'
          _notificationsPlugin.cancel(id: 911);
          debugPrint('🚨 SMS ALERT: CANCEL action triggered!');
        }
      },
    );

    // Create notification channels
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_sosChannel);
    await androidImpl?.createNotificationChannel(_fcmChannel);

    // Firebase Messaging setup
    await _setupFCM();
  }

  // ── FCM Setup ─────────────────────────────────────────────────────────────────
  static Future<void> _setupFCM() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      final NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('🔔 FCM Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Retry token fetch up to 3 times (fixes MIUI/Play Services delay)
        try {
          String? token;
          for (int attempt = 1; attempt <= 3; attempt++) {
            try {
              token = await messaging.getToken();
              if (token != null) {
                debugPrint('📱 FCM Token (attempt $attempt): $token');
                break;
              }
            } catch (e) {
              debugPrint('⚠️ FCM Token attempt $attempt failed: $e');
              if (attempt < 3) {
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          }
          if (token == null) {
            debugPrint(
              '⚠️ FCM Token unavailable after 3 attempts. Will retry on next launch.',
            );
          }
        } catch (e) {
          debugPrint('⚠️ FCM Token fetch failed: $e');
        }

        messaging.onTokenRefresh.listen((newToken) {
          debugPrint('📱 FCM Token refreshed: $newToken');
          // TODO: Send updated token to your backend
        });

        // Foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 FCM Foreground: ${message.messageId}');
          showFCMNotification(message);
        });

        // Notification tapped while app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('📨 FCM Opened: ${message.messageId}');
          // TODO: Navigate based on message.data
        });

        // App launched from terminated-state notification
        try {
          final RemoteMessage? initial = await messaging.getInitialMessage();
          if (initial != null) {
            debugPrint('🚀 FCM Launch message: ${initial.messageId}');
          }
        } catch (e) {
          debugPrint('⚠️ FCM getInitialMessage failed: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ FCM setup failed: $e');
      // App continues to work normally without push notifications
    }
  }

  // ── Show FCM notification locally ─────────────────────────────────────────────
  static Future<void> showFCMNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'fcm_channel',
          'Push Notifications',
          channelDescription: 'Firebase Cloud Messaging push notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    // v21+: show() uses named parameters
    await _notificationsPlugin.show(
      id: notification.hashCode,
      title: notification.title ?? 'Notification',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  // ── Get FCM Token ─────────────────────────────────────────────────────────────
  static Future<String?> getFCMToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  // ── SOS Countdown ─────────────────────────────────────────────────────────────
  static Future<bool> showSOSCountdown({
    required Function onComplete,
    required Function onCancel,
  }) async {
    _isCancelled = false;
    int secondsRemaining = 5;

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isCancelled) {
        timer.cancel();
        onCancel();
        await _notificationsPlugin.cancel(id: 911);
        return;
      }

      if (secondsRemaining <= 0) {
        timer.cancel();
        await _notificationsPlugin.cancel(id: 911);
        onComplete();
        return;
      }

      await _updateSOSNotification(secondsRemaining);
      secondsRemaining--;
    });

    return true;
  }

  static Future<void> _updateSOSNotification(int seconds) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'sos_channel',
          'SOS Alerts',
          channelDescription: 'High priority SOS countdown notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'SOS Alert',
          ongoing: true,
          autoCancel: false,
          color: Colors.red,
          icon: '@mipmap/ic_launcher',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'cancel_sos',
              'CANCEL',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        );

    // v21+: show() uses named parameters
    await _notificationsPlugin.show(
      id: 911,
      title: '🚨 SOS ALERT',
      body:
          'Sending SMS Alert to Guradian IN $seconds SECONDS...\nTAP CANCEL TO STOP',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }
}
