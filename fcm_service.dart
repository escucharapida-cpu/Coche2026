import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService instance = FCMService._internal();
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // قناة إشعارات طوارئ للسيارات
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'car_shield_alerts_channel',
    'تنبيهات السيارة العاجلة',
    description: 'تنبيهات فورية عند وجود مشكلة في سيارتك (عرقلة، زجاج مفتوح، صدمة)',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    // 1. طلب الصلاحيات من المستخدم
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ تم منح صلاحية الإشعارات الفورية");
    }

    // 2. إعداد القناة على نظام أندرويد
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      ),
    );

    await _localNotifications.initialize(initializationSettings);

    // 3. حفظ وتحديث الـ FCM Token الخاص بالمستخدم في قاعدة البيانات
    await _saveDeviceToken();
    _fcm.onTokenRefresh.listen((newToken) => _updateTokenInDb(newToken));

    // 4. الاستماع للإشعارات أثناء تشغيل التطبيق في الواجهة (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> _saveDeviceToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _updateTokenInDb(token);
    }
  }

  Future<void> _updateTokenInDb(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // يتم حفظ التوكن في وثيقة المستخدم الخاصة لكي تستخدمه Cloud Functions
    // ولا يستطيع أي مستخدم آخر في التطبيق قراءته!
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title ?? "🚨 تنبيه بشأن سيارتك!",
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}