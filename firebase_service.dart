import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/car_qr_model.dart';
import '../models/alert_model.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // الحصول على معرف المستخدم الحالي
  String get currentUid => _auth.currentUser?.uid ?? '';

  // 1. توليد وإضافة سيارة جديدة للمستخدم برمز QR فريد
  Future<CarQRModel> registerNewCar({
    required String carPlate,
    required String carModel,
    required String carColor,
    String? customNote,
    bool allowEmergencyCalls = true,
  }) async {
    final uid = currentUid;
    if (uid.isEmpty) throw Exception("يجب تسجيل الدخول أولاً");

    // إنشاء توكن مشفر عشوائي غير قابل للتخمين للـ QR
    final qrToken = "CS-${_uuid.v4().substring(0, 8).toUpperCase()}";
    final carDocRef = _firestore.collection('users').doc(uid).collection('cars').doc();

    final car = CarQRModel(
      id: carDocRef.id,
      ownerUid: uid,
      qrToken: qrToken,
      carPlate: carPlate,
      carModel: carModel,
      carColor: carColor,
      customNote: customNote,
      allowEmergencyCalls: allowEmergencyCalls,
      createdAt: DateTime.now(),
    );

    // عملية كتابة مجمعة Batch لضمان التزامن
    final batch = _firestore.batch();

    // حفظ في سيارات المستخدم الخاصة
    batch.set(carDocRef, car.toPrivateMap());

    // حفظ في السجل العام المفهرس برمز qrToken (بدون أي أرقام هواتف!)
    final publicRef = _firestore.collection('cars_public').doc(qrToken);
    batch.set(publicRef, {
      ...car.toPublicMap(),
      'ownerUid': uid, // يستخدم فقط من قبل Cloud Functions لإرسال التنبيه
    });

    await batch.commit();
    return car;
  }

  // 2. البحث عن بيانات السيارة بواسطة رمز الـ QR عند المسح
  Future<CarQRModel?> lookupCarByQr(String qrToken) async {
    final doc = await _firestore.collection('cars_public').doc(qrToken).get();
    if (!doc.exists) return null;
    return CarQRModel.fromFirestore(doc);
  }

  // 3. إرسال تنبيه فوري من الماسح إلى صاحب السيارة
  // عند كتابة هذا المستند، تعمل Firebase Cloud Function تلقائياً
  // وتبحث عن FCM Token الخاص بـ ownerUid وترسل الإشعار له فوراً
  Future<void> sendAlert({
    required String qrToken,
    required String carPlate,
    required AlertType alertType,
    String? customMessage,
  }) async {
    final alertRef = _firestore.collection('alerts').doc();
    
    // معرف عشوائي للماسح لحماية خصوصيته أيضاً
    final anonymousSenderId = "SND-${_uuid.v4().substring(0, 6)}";

    await alertRef.set({
      'id': alertRef.id,
      'qrToken': qrToken,
      'carPlate': carPlate,
      'alertType': alertType.name,
      'title': alertType.title,
      'body': customMessage?.isNotEmpty == true ? customMessage : alertType.description,
      'senderSessionId': anonymousSenderId,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent',
    });
  }

  // 4. الاستماع المباشر للسيارات المسجلة للمستخدم الحالي
  Stream<List<CarQRModel>> getUserCarsStream() {
    final uid = currentUid;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cars')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => CarQRModel.fromFirestore(d)).toList());
  }

  // 5. الاستماع المباشر للتنبيهات الواردة لصاحب السيارة
  Stream<List<AlertModel>> getIncomingAlertsStream() {
    final uid = currentUid;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('received_alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => AlertModel.fromFirestore(d)).toList());
  }
}