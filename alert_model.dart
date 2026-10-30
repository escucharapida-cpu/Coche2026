import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType {
  blocking('عرقلة حركة سير', 'سيارتك تقف في مكان يعيق خروج أو مرور الآخرين'),
  windowOpen('الزجاج مفتوح', 'أحد نوافذ سيارتك مفتوحة جزئياً أو كلياً'),
  lightsOn('الإنارة مشتعلة', 'أضواء سيارتك تركت مشتعلة مما قد يفرغ البطارية'),
  carAlarm('إنذار السيارة يطلق صوتاً', 'جهاز الإنذار في سيارتك يعمل بشكل متكرر'),
  hitOrScratch('صدمة أو احتكاك', 'تعرضت سيارتك للاحتكاك أو الصدم أثناء التوقف'),
  custom('رسالة مخصصة', 'تنبيه شخصي من شخص بالقرب من سيارتك');

  final String title;
  final String description;
  const AlertType(this.title, this.description);
}

class AlertModel {
  final String id;
  final String qrToken;
  final String carPlate;
  final AlertType alertType;
  final String? customMessage;
  final String senderSessionId; // معرف جلسة الماسح مجهول الهوية
  final DateTime timestamp;
  final bool isRead;

  AlertModel({
    required this.id,
    required this.qrToken,
    required this.carPlate,
    required this.alertType,
    this.customMessage,
    required this.senderSessionId,
    required this.timestamp,
    this.isRead = false,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      qrToken: data['qrToken'] ?? '',
      carPlate: data['carPlate'] ?? '',
      alertType: AlertType.values.firstWhere(
        (e) => e.name == data['alertType'],
        orElse: () => AlertType.custom,
      ),
      customMessage: data['customMessage'],
      senderSessionId: data['senderSessionId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'qrToken': qrToken,
      'carPlate': carPlate,
      'alertType': alertType.name,
      'customMessage': customMessage,
      'senderSessionId': senderSessionId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
  }
}