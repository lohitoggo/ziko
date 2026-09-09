import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/wallet_provider.dart';
import '../../../core/theme/app_theme.dart';

class WalletScreen extends ConsumerWidget {
  final String userId;
  const WalletScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(userWalletBalanceProvider(userId));
    final transactionsAsync = ref.watch(userWalletTransactionsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Ziko Signature Premium Gradient Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ziko Wallet',
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Manage your credits & refunds',
                      style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Scrollable Wallet Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF45D27).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL ZIKO CREDITS', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
                            const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                          ],
                        ),
                        const SizedBox(height: 12),
                        balanceAsync.when(
                          data: (bal) => Text('₹${bal.toStringAsFixed(2)}', style: GoogleFonts.urbanist(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                          loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white))),
                          error: (_, _) => Text('₹0.00', style: GoogleFonts.urbanist(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                        const SizedBox(height: 12),
                        Text('Use credits during checkout for instant discounts & auto refunds.', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Info Alert
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ক্যানসেল হওয়া অর্ডারের রিফান্ডের টাকা সরাসরি আপনার Ziko Wallet-এ যোগ হয়।',
                            style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Transactions Header
                  Text('TRANSACTION HISTORY', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.charcoal)),
                  const SizedBox(height: 12),

                  // Transactions List
                  transactionsAsync.when(
                    loading: () => const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (txs) {
                      if (txs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('কোনো লেনদেনের ইতিহাস পাওয়া যায়নি', style: GoogleFonts.urbanist(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txs.length,
                        itemBuilder: (ctx, i) {
                          final tx = txs[i];
                          final isCredit = tx.type == 'credit';
                          final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isCredit ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit ? Icons.add_card_rounded : Icons.shopping_bag_outlined,
                                    color: isCredit ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tx.title, style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 14)),
                                      if (tx.description.isNotEmpty) Text(tx.description, style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey.shade600)),
                                      Text(dateStr, style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey.shade400)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${isCredit ? "+" : "-"}₹${tx.amount.toInt()}',
                                  style: GoogleFonts.urbanist(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: isCredit ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
