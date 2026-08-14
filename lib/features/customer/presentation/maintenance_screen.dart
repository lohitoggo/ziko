import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MaintenanceScreen extends StatelessWidget {
  final String? message;
  const MaintenanceScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle_outlined, size: 100, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'অ্যাপে কাজ চলছে',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.charcoal),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'আমরা অ্যাপটিকে আরও উন্নত করার জন্য কাজ করছি। অনুগ্রহ করে কিছুক্ষণ পর আবার চেষ্টা করুন।',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
