import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/fcm_service.dart';
import 'screens/car_dashboard_screen.dart';

// معالج إشعارات الخلفية عندما يكون التطبيق مغلقاً تماماً
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("🚨 استلام إشعار في الخلفية: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة فايربيس
  await Firebase.initializeApp();

  // تفعيل استقبال إشعارات الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // إعداد خدمة الإشعارات المحلية والفورية
  await FCMService.instance.initialize();

  // تسجيل دخول مجهول أو التحقق من المستخدم الحالي
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(const CarPrivacyApp());
}

class CarPrivacyApp extends StatelessWidget {
  const CarPrivacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarShield | درع السيارة',
      debugShowCheckedModeBanner: false,
      
      // الدعم الكامل للغة العربية
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFF59E0B), // لون كهرماني تحذيري مميز
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const CarDashboardScreen(),
    );
  }
}