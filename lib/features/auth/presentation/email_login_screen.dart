import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক ইমেইল দিন')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(supabaseAuthControllerProvider).signInWithEmail(email);
      if (mounted) {
        _showOtpDialog(email);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOtpDialog(String email) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('ইমেইল ওটিপি'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$email ঠিকানায় একটি কোড পাঠানো হয়েছে।'),
            const SizedBox(height: 16),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '৬ ডিজিটের কোড'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(supabaseAuthControllerProvider).verifyEmailOtp(email, otpCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ভুল ওটিপি: $e')));
              }
            },
            child: const Text('ভেরিফাই করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Ziko', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.primary)),
              const SizedBox(height: 10),
              const Text('আপনার ইমেইল দিয়ে লগইন করুন', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'ইমেইল এড্রেস',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('ওটিপি পাঠান'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
