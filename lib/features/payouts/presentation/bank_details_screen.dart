import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/payout_provider.dart';
import '../data/payout_model.dart';
import '../../../core/theme/app_theme.dart';

class BankDetailsScreen extends ConsumerStatefulWidget {
  final String userId;
  const BankDetailsScreen({super.key, required this.userId});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _holderCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _accountCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _upiCtrl;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _holderCtrl = TextEditingController();
    _bankCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _ifscCtrl = TextEditingController();
    _upiCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _bankCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBankDetails() async {
    final holder = _holderCtrl.text.trim();
    final bank = _bankCtrl.text.trim();
    final acc = _accountCtrl.text.trim();
    final ifsc = _ifscCtrl.text.trim();
    final upi = _upiCtrl.text.trim();

    // Ensure at least one payment method is provided
    final hasBank = acc.isNotEmpty && ifsc.isNotEmpty;
    final hasUpi = upi.isNotEmpty;

    if (!hasBank && !hasUpi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কমপক্ষে ব্যাংক একাউন্ট নম্বর অথবা UPI ID পূরণ করুন'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final details = BankDetails(
        userId: widget.userId,
        accountHolderName: holder.isEmpty ? 'N/A' : holder,
        bankName: bank.isEmpty ? 'N/A' : bank,
        accountNumber: acc,
        ifscCode: ifsc.toUpperCase(),
        upiId: upi,
      );

      await ref.read(payoutRepositoryProvider).saveBankDetails(details);
      ref.invalidate(userBankDetailsProvider(widget.userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ব্যাংক ও UPI তথ্য সফলভাবে সেভ করা হয়েছে ✅'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, details);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সেভ করতে সমস্যা হয়েছে: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bankAsync = ref.watch(userBankDetailsProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: Text('ব্যাংক ও UPI ডিটেইলস', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: bankAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (details) {
          if (!_isInitialized && details != null) {
            _holderCtrl.text = details.accountHolderName == 'N/A' ? '' : details.accountHolderName;
            _bankCtrl.text = details.bankName == 'N/A' ? '' : details.bankName;
            _accountCtrl.text = details.accountNumber;
            _ifscCtrl.text = details.ifscCode;
            _upiCtrl.text = details.upiId;
            _isInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'আপনার পে-আউট / উইথড্রয়াল রিফান্ড পাওয়ার জন্য ব্যাংক একাউন্ট অথবা UPI ID পূরণ করুন।',
                            style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Option 1: Bank Account Details
                  Text('১. ব্যাংক অ্যাকাউন্ট তথ্য (Bank Account)', style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: _holderCtrl,
                    decoration: const InputDecoration(labelText: 'একাউন্ট হোল্ডারের নাম', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _bankCtrl,
                    decoration: const InputDecoration(labelText: 'ব্যাংকের নাম (e.g. SBI, HDFC)', prefixIcon: Icon(Icons.account_balance_outlined)),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _accountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'একাউন্ট নম্বর', prefixIcon: Icon(Icons.numbers_outlined)),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _ifscCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'IFSC Code', prefixIcon: Icon(Icons.code_outlined)),
                  ),
                  const SizedBox(height: 24),

                  // Option 2: UPI ID
                  Text('২. UPI আইডি (Instant PhonePe / GPay / PayTM)', style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _upiCtrl,
                    decoration: const InputDecoration(labelText: 'UPI ID (e.g. 9876543210@ybl / merchant@paytm)', prefixIcon: Icon(Icons.qr_code_outlined)),
                  ),
                  const SizedBox(height: 35),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveBankDetails,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('সেভ করুন', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
