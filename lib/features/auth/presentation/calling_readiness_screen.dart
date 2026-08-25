import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';

class CallingReadinessScreen extends StatefulWidget {
  final Widget destination;
  const CallingReadinessScreen({super.key, required this.destination});

  @override
  State<CallingReadinessScreen> createState() => _CallingReadinessScreenState();
}

class _CallingReadinessScreenState extends State<CallingReadinessScreen> with WidgetsBindingObserver {
  bool _isOverlayGranted = false;
  bool _isBatteryIgnored = false;
  bool _isNotificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<void> _checkAll() async {
    final overlay = await Permission.systemAlertWindow.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    final notify = await Permission.notification.isGranted;

    if (mounted) {
      setState(() {
        _isOverlayGranted = overlay;
        _isBatteryIgnored = battery;
        _isNotificationGranted = notify;
      });

      // AUTO-PROCEED if all granted
      if (overlay && battery && notify) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => widget.destination));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.ring_volume_rounded, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Ready to Receive\nOrder Calls?',
                style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.charcoal, height: 1.2),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enable these 3 settings to ensure you never miss a high-priority order call.',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 40),

              _permissionItem(
                'Display Over Other Apps',
                'Allows call screen to pop up instantly.',
                _isOverlayGranted,
                () => openAppSettings(), // Unlocked and reliable
              ),
              const SizedBox(height: 16),
              _permissionItem(
                'Ignore Battery Optimization',
                'Keeps the app সজাগ even in sleep mode.',
                _isBatteryIgnored,
                () => openAppSettings(), // Unlocked and reliable
              ),
              const SizedBox(height: 16),
              _permissionItem(
                'Notifications',
                'Essential for receiving order signals.',
                _isNotificationGranted,
                () => openAppSettings(), // Unlocked and reliable
              ),

              const SizedBox(height: 24),
              // ADDED CLEAR GUIDE FOR REALME/OPPO USERS
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.withValues(alpha: 0.1))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.info_outline_rounded, color: Colors.blue.shade700, size: 18), const SizedBox(width: 8), Text('How to enable?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                    const SizedBox(height: 10),
                    _instructionRow('1. Click any button to open App Info.'),
                    _instructionRow('2. Find "Display over other apps" & Allow.'),
                    _instructionRow('3. Set "Battery" to "Unrestricted".'),
                    _instructionRow('4. Ensure "Auto-launch" is ON.'),
                  ],
                ),
              ),

              const Spacer(),
              const Center(
                child: Text(
                  'Your app will open once all settings are ON',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructionRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.3))),
        ],
      ),
    );
  }

  Widget _permissionItem(String title, String subtitle, bool isGranted, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, // ALWAYS CLICKABLE NOW
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isGranted ? Colors.green.withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isGranted ? Colors.green.withValues(alpha: 0.2) : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(isGranted ? Icons.check_circle_rounded : Icons.pending_rounded, 
                 color: isGranted ? Colors.green : Colors.orange, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (!isGranted) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
