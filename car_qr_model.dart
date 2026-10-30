import 'package:cloud_firestore/cloud_firestore.dart';

class CarQRModel {
  final String id;              // معرف المستند في Firestore
  final String ownerUid;        // معرف صاحب السيارة (Firebase Auth UID)
  final String qrToken;         // التوكن المجهول المشفر الموجود داخل رمز الـ QR
  final String carPlate;        // رقم اللوحة المعروض اختياريًا
  final String carModel;        // نوع وموديل السيارة
  final String carColor;        // لون السيارة
  final String? customNote;     // ملاحظة مخصصة (مثال: متواجد بالمقهى المجاور)
  final bool allowEmergencyCalls; // هل يسمح بتحويل مكالمة هاتفية عبر مزود وسيط
  final DateTime createdAt;

  CarQRModel({
    required this.id,
    required this.ownerUid,
    required this.qrToken,
    required this.carPlate,
    required this.carModel,
    required this.carColor,
    this.customNote,
    this.allowEmergencyCalls = true,
    required this.createdAt,
  });

  // تحويل من Firestore
  factory CarQRModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CarQRModel(
      id: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      qrToken: data['qrToken'] ?? '',
      carPlate: data['carPlate'] ?? '',
      carModel: data['carModel'] ?? '',
      carColor: data['carColor'] ?? '',
      customNote: data['customNote'],
      allowEmergencyCalls: data['allowEmergencyCalls'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ما يُحفظ في مجموعة "cars_public" المتاحة للقراءة بالبحث بالـ qrToken فقط
  // لاحظ: لا يحتوي أبداً على رقم الهاتف أو الـ FCM Token الخاص بالسائق!
  Map<String, dynamic> toPublicMap() {
    return {
      'qrToken': qrToken,
      'carPlate': carPlate,
      'carModel': carModel,
      'carColor': carColor,
      'customNote': customNote,
      'allowEmergencyCalls': allowEmergencyCalls,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ما يُحفظ في مستند السائق الخاص
  Map<String, dynamic> toPrivateMap() {
    return {
      'id': id,
      'ownerUid': ownerUid,
      'qrToken': qrToken,
      'carPlate': carPlate,
      'carModel': carModel,
      'carColor': carColor,
      'customNote': customNote,
      'allowEmergencyCalls': allowEmergencyCalls,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}