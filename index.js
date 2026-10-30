const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * دالة سحابية تعمل تلقائياً عند قيام أي شخص بمسح الـ QR وإرسال تنبيه
 * تقوم بالبحث عن صاحب السيارة وإرسال إشعار فوري له دون أن يرى الماسح التوكن أو رقم الهاتف!
 */
exports.onCarAlertCreated = functions.firestore
  .document("alerts/{alertId}")
  .onCreate(async (snap, context) => {
    const alertData = snap.data();
    const { qrToken, alertType, title, body, carPlate } = alertData;

    try {
      // 1. البحث عن السيارة في الفهرس العام لمعرفة صاحبها
      const carPublicDoc = await admin.firestore()
        .collection("cars_public")
        .doc(qrToken)
        .get();

      if (!carPublicDoc.exists) {
        console.error("لم يتم العثور على سيارة مسجلة برمز:", qrToken);
        return null;
      }

      const ownerUid = carPublicDoc.data().ownerUid;

      // 2. جلب توكن الإشعار (FCM Token) الخاص بالسائق من ملفه السري
      const userDoc = await admin.firestore()
        .collection("users")
        .doc(ownerUid)
        .get();

      if (!userDoc.exists || !userDoc.data().fcmToken) {
        console.warn("السائق ليس لديه توكن إشعار نشط:", ownerUid);
        return null;
      }

      const fcmToken = userDoc.data().fcmToken;

      // 3. حفظ نسخة من التنبيه في صندوق إشعارات السائق الداخلي
      await admin.firestore()
        .collection("users")
        .doc(ownerUid)
        .collection("received_alerts")
        .doc(context.params.alertId)
        .set({
          ...alertData,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
        });

      // 4. بناء وإرسال الإشعار الفوري عالي الأهمية (High Priority Push Notification)
      const payload = {
        token: fcmToken,
        notification: {
          title: `🚨 تنبيه سيارة (${carPlate || "سيارتك"}): ${title || "تنبيه جديد"}`,
          body: body || "شخص ما بجوار سيارتك قام بمسح الرمز للتنبيه.",
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          alertId: context.params.alertId,
          qrToken: qrToken,
          alertType: alertType || "general",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "car_shield_alerts_channel",
            sound: "default",
            priority: "max",
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(payload);
      console.log("✅ تم إرسال الإشعار بنجاح لصاحب السيارة:", response);

      // تحديث حالة التنبيه في السجل
      return snap.ref.update({ status: "delivered", deliveredAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (error) {
      console.error("❌ خطأ أثناء معالجة وإرسال التنبيه:", error);
      return snap.ref.update({ status: "failed", error: error.message });
    }
  });