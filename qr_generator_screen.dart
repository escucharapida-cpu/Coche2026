import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/car_qr_model.dart';

class QRGeneratorScreen extends StatefulWidget {
  final CarQRModel car;

  const QRGeneratorScreen({super.key, required this.car});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;

  // خيارات ثيم الملصق
  int _selectedStyleIndex = 0;
  final List<Color> _accentColors = [
    const Color(0xFFF59E0B), // كهرماني
    const Color(0xFF3B82F6), // أزرق رياضي
    const Color(0xFF10B981), // أخضر زمردي
    const Color(0xFFEF4444), // أحمر تحذيري
  ];

  // دالة التقاط وحفظ الملصق
  Future<void> _captureAndShareSticker() async {
    setState(() => _isSaving = true);
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 3.0, // دقة طباعة فائقة
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/car_sticker_${widget.car.carPlate}.png').create();
        await imagePath.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: 'ملصق حماية خصوصية لسيارتي (${widget.car.carPlate}) - جاهز للطباعة واللصق على الزجاج',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الملصق: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _accentColors[_selectedStyleIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملصق الـ QR لسيارتك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'مشاركة وطباعة الملصق',
            onPressed: _isSaving ? null : _captureAndShareSticker,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // بطاقة التنبيه بالخصوصية
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'رقم هاتفك محمي بنسبة 100%. عند مسح هذا الرمز، سيتلقى هاتفك تنبيهاً مباشراً دون إظهار أي معلومة شخصية.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // منطقة الملصق القابلة للتصوير والطباعة
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: currentColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: currentColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // رأس الملصق
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: currentColor, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'امسح للتنبيه عند الطوارئ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'عرقلة سير • زجاج مفتوح • إضاءة مشتعلة',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 20),

                    // حاوية رمز الـ QR
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: QrImageView(
                        data: widget.car.qrToken,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // كبسولة رقم اللوحة والموديل
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car_rounded, color: currentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.car.carModel} • ${widget.car.carPlate}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'خدمة حماية خصوصية السيارات | CarShield',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ألوان تخصيص الملصق
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_accentColors.length, (index) {
                final isSelected = _selectedStyleIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStyleIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accentColors[index],
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 30),

            // زر الحفظ والمشاركة
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _captureAndShareSticker,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded),
              label: Text(_isSaving ? 'جارٍ المعالجة...' : 'تنزيل الملصق للطباعة (PNG)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}