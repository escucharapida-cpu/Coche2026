import 'package:flutter/material.dart';
import '../models/car_qr_model.dart';
import '../models/alert_model.dart';
import '../services/firebase_service.dart';
import 'qr_generator_screen.dart';
import 'qr_scanner_screen.dart';

class CarDashboardScreen extends StatefulWidget {
  const CarDashboardScreen({super.key});

  @override
  State<CarDashboardScreen> createState() => _CarDashboardScreenState();
}

class _CarDashboardScreenState extends State<CarDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showAddCarDialog() {
    final plateController = TextEditingController();
    final modelController = TextEditingController();
    final colorController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('تسجيل سيارة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: plateController,
                decoration: const InputDecoration(labelText: 'رقم اللوحة (مثال: أ ب ج 1234)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: 'نوع وموديل السيارة (مثال: كامري 2023)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'لون السيارة (مثال: أبيض لؤلؤي)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              if (plateController.text.isEmpty || modelController.text.isEmpty) return;
              Navigator.pop(ctx);
              await FirebaseService.instance.registerNewCar(
                carPlate: plateController.text.trim(),
                carModel: modelController.text.trim(),
                carColor: colorController.text.trim(),
              );
            },
            child: const Text('إنشاء وتوليد الـ QR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('درع خصوصية السيارة', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car_rounded), text: 'سياراتي وملصقاتي'),
            Tab(icon: Icon(Icons.notifications_active_rounded), text: 'سجل التنبيهات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تبويب 1: سياراتي
          _buildCarsTab(),

          // تبويب 2: سجل التنبيهات
          _buildAlertsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('مسح كود سيارة'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QRScannerScreen()),
          );
        },
      ),
    );
  }

  Widget _buildCarsTab() {
    return StreamBuilder<List<CarQRModel>>(
      stream: FirebaseService.instance.getUserCarsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final cars = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // زر إضافة سيارة جديدة
            OutlinedButton.icon(
              onPressed: _showAddCarDialog,
              icon: const Icon(Icons.add_circle_outline, color: Colors.amber),
              label: const Text('إضافة سيارة وتوليد ملصق QR جديد', style: TextStyle(color: Colors.amber)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            if (cars.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    const Text('لم تقم بتسجيل أي سيارة حتى الآن'),
                    const SizedBox(height: 6),
                    Text('أضف سيارتك الأولى لتوليد رمز QR خاص بها ولصقه على الزجاج',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ],
                ),
              ),

            ...cars.map((car) => Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      child: Icon(Icons.directions_car),
                    ),
                    title: Text('${car.carModel} (${car.carColor})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('اللوحة: ${car.carPlate} • الرمز: ${car.qrToken}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => QRGeneratorScreen(car: car)),
                        );
                      },
                      child: const Text('الملصق'),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<List<AlertModel>>(
      stream: FirebaseService.instance.getIncomingAlertsStream(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) {
          return const Center(child: Text('لا توجد أي تنبيهات واردة لسياراتك حتى الآن'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 30),
                title: Text(alert.alertType.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(alert.customMessage ?? alert.alertType.description),
                trailing: Text(
                  '${alert.timestamp.hour}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
}