import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/firebase_service.dart';
import '../models/car_qr_model.dart';
import '../models/alert_model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // البحث عن السيارة برمز الـ QR
      final car = await FirebaseService.instance.lookupCarByQr(code.trim());

      if (!mounted) return;

      if (car == null) {
        _showErrorDialog("لم يتم العثور على سيارة مرتبطة بهذا الرمز!");
        setState(() => _isProcessing = false);
        return;
      }

      // إيقاف الكاميرا مؤقتاً أثناء عرض خيارات التنبيه
      await _controller.stop();

      // فتح نافذة إرسال التنبيه
      if (mounted) {
        await _showSendAlertDialog(car);
        // إعادة تشغيل الكاميرا عند إغلاق النافذة
        await _controller.start();
      }
    } catch (e) {
      _showErrorDialog("حدث خطأ أثناء معالجة الرمز: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSendAlertDialog(CarQRModel car) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _QuickAlertSheet(car: car),
    );
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('تنبيه', style: TextStyle(color: Colors.amber)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قارئ رمز السيارة'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                  color: Colors.amber,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ماسح الكاميرا
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // إطار توجيه المسح المرئي
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'وجّه الكاميرا نحو ملصق السيارة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.amber),
                    SizedBox(height: 16),
                    Text('جارٍ التحقق من السيارة وإعداد التنبيه...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// نافذة اختيار وإرسال التنبيه السريع
class _QuickAlertSheet extends StatefulWidget {
  final CarQRModel car;
  const _QuickAlertSheet({required this.car});

  @override
  State<_QuickAlertSheet> createState() => _QuickAlertSheetState();
}

class _QuickAlertSheetState extends State<_QuickAlertSheet> {
  bool _isSending = false;
  final TextEditingController _customMsgController = TextEditingController();

  Future<void> _send(AlertType type, {String? customText}) async {
    setState(() => _isSending = true);
    try {
      await FirebaseService.instance.sendAlert(
        qrToken: widget.car.qrToken,
        carPlate: widget.car.carPlate,
        alertType: type,
        customMessage: customText,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('✅ تم إرسال التنبيه الفوري لصاحب السيارة بنجاح دون كشف هويتك!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مقبض النافذة
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),

          // معلومات السيارة المعروضة للماسح بأمان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_car_filled_rounded, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.car.carModel} • ${widget.car.carColor}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'اللوحة: ${widget.car.carPlate}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const Text(
            'اختر نوع التنبيه لإرساله لصاحب السيارة فوراً:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),

          // قائمة الخيارات السريعة
          _alertTile(AlertType.blocking, Icons.no_crash_rounded, Colors.orange),
          _alertTile(AlertType.windowOpen, Icons.sensor_window_rounded, Colors.cyan),
          _alertTile(AlertType.lightsOn, Icons.lightbulb_rounded, Colors.yellow),
          _alertTile(AlertType.carAlarm, Icons.volume_up_rounded, Colors.redAccent),
          _alertTile(AlertType.hitOrScratch, Icons.warning_amber_rounded, Colors.pinkAccent),
          
          const SizedBox(height: 12),
          // حقل رسالة مخصصة
          TextField(
            controller: _customMsgController,
            decoration: InputDecoration(
              hintText: 'أو اكتب رسالة مخصصة أخرى...',
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.amber),
                onPressed: _isSending
                    ? null
                    : () {
                        if (_customMsgController.text.trim().isNotEmpty) {
                          _send(AlertType.custom, customText: _customMsgController.text.trim());
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(AlertType type, IconData icon, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(type.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(type.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      trailing: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
      onTap: _isSending ? null : () => _send(type),
    );
  }
}