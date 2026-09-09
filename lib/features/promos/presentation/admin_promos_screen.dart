import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/promo_provider.dart';
import '../data/promo_model.dart';
import '../../../core/theme/app_theme.dart';

class AdminPromosScreen extends ConsumerWidget {
  const AdminPromosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promosAsync = ref.watch(allPromoCodesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('কুপন ও প্রোমোকোড ম্যানেজমেন্ট', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPromoDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('নতুন কুপন', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: promosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('কোনো কুপন বা প্রোমোকোড তৈরি করা হয়নি', style: GoogleFonts.urbanist(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: promos.length,
            itemBuilder: (ctx, i) {
              final promo = promos[i];
              return _PromoCard(promo: promo);
            },
          );
        },
      ),
    );
  }

  void _showAddPromoDialog(BuildContext context, WidgetRef ref) {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController(text: '0');
    final maxDiscountCtrl = TextEditingController(text: '1000');
    String discountType = 'flat';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('নতুন কুপন যোগ করুন', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'কুপন কোড (e.g. WELCOME50)', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('ডিসকাউন্ট টাইপ:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Flat (₹)'),
                      selected: discountType == 'flat',
                      onSelected: (_) => setModalState(() => discountType = 'flat'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Percentage (%)'),
                      selected: discountType == 'percentage',
                      onSelected: (_) => setModalState(() => discountType = 'percentage'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: discountType == 'flat' ? 'ডিসকাউন্ট পরিমাণ (₹)' : 'ডিসকাউন্ট শতাংশ (%)',
                    prefixIcon: const Icon(Icons.discount_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minOrderCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'মিনিমাম অর্ডার টাকা (₹)', prefixIcon: Icon(Icons.shopping_bag_outlined)),
                ),
                if (discountType == 'percentage') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxDiscountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'সর্বোচ্চ ছাড়ের সীমা (₹)', prefixIcon: Icon(Icons.vertical_align_top_outlined)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final code = codeCtrl.text.trim();
                final val = double.tryParse(valueCtrl.text) ?? 0.0;
                if (code.isEmpty || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক কোড ও ছাড়ের পরিমাণ দিন')));
                  return;
                }

                setModalState(() => isSaving = true);
                try {
                  final newPromo = PromoCode(
                    id: '',
                    code: code,
                    discountType: discountType,
                    discountValue: val,
                    minOrderAmount: double.tryParse(minOrderCtrl.text) ?? 0.0,
                    maxDiscount: double.tryParse(maxDiscountCtrl.text) ?? 1000.0,
                    isActive: true,
                    expiryDate: DateTime.now().add(const Duration(days: 30)),
                  );

                  await ref.read(promoRepositoryProvider).createPromoCode(newPromo);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কুপন সফলভাবে তৈরি হয়েছে ✅'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setModalState(() => isSaving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('সেভ করুন'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends ConsumerWidget {
  final PromoCode promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(promoRepositoryProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(promo.code, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 1)),
              ),
              Switch(
                value: promo.isActive,
                activeThumbColor: Colors.green,
                onChanged: (v) => repo.togglePromoStatus(promo.id, v),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            promo.discountType == 'flat'
                ? 'ছাড়: ₹${promo.discountValue.toInt()} Flat'
                : 'ছাড়: ${promo.discountValue.toInt()}% (সর্বোচ্চ ₹${promo.maxDiscount.toInt()})',
            style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('মিনিমাম অর্ডার: ₹${promo.minOrderAmount.toInt()}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          if (promo.expiryDate != null)
            Text('মেয়াদ: ${DateFormat('dd MMM yyyy').format(promo.expiryDate!)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => repo.deletePromoCode(promo.id),
            ),
          ),
        ],
      ),
    );
  }
}
