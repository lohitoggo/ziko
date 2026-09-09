import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/rider_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../payouts/providers/payout_provider.dart';
import '../../payouts/presentation/bank_details_screen.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class RiderEarningsTab extends ConsumerWidget {
  const RiderEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(myCompletedDeliveriesProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: completedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('সমস্যা: $e')),
        data: (orders) {
          final totalEarnings = orders.fold<double>(
            0,
            (sum, o) => sum + ((o['delivery_charge'] ?? 0).toDouble()),
          );

          final now = DateTime.now();
          final todayEarnings = orders.where((o) {
            final deliveredAtStr = o['delivered_at'] as String?;
            if (deliveredAtStr == null) return false;
            final deliveredAt = DateTime.tryParse(deliveredAtStr);
            if (deliveredAt == null) return false;
            return deliveredAt.day == now.day && 
                   deliveredAt.month == now.month && 
                   deliveredAt.year == now.year;
          }).fold<double>(0, (sum, o) => sum + ((o['delivery_charge'] ?? 0).toDouble()));

          final totalCodCash = orders.where((o) => (o['payment_method'] ?? '').toString().toLowerCase() == 'cod')
              .fold<double>(0, (sum, o) => sum + ((o['total_amount'] ?? 0).toDouble()));

          // Calculate Withdrawable Balance
          final requests = user != null ? (ref.watch(userPayoutRequestsProvider(user.uid)).value ?? []) : [];
          final double alreadyPaidOrPending = requests
              .where((r) => r.status == 'pending' || r.status == 'paid')
              .fold<double>(0.0, (sum, r) => sum + r.amount);

          final double withdrawableBalance = (totalEarnings - alreadyPaidOrPending).clamp(0.0, totalEarnings);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Earnings Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text('মোট অর্জিত আয়', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('₹${totalEarnings.toInt()}', 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'উইথড্রযোগ্য ব্যালেন্স: ₹${withdrawableBalance.toInt()}',
                          style: GoogleFonts.urbanist(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _SmallStat(label: 'আজকের আয়', value: '₹${todayEarnings.toInt()}'),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _SmallStat(label: 'সংগৃহীত ক্যাশ', value: '₹${totalCodCash.toInt()}'),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _SmallStat(label: 'মোট ডেলিভারি', value: '${orders.length}'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _handleWithdrawal(context, ref, totalEarnings),
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        label: const Text('টাকা তুলুন (Withdraw)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // COD Cash Collection Info Card
                if (totalCodCash > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: const Icon(Icons.payments_rounded, color: Colors.amber, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('সংগৃহীত ক্যাশ (COD Cash on Hand)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              const Text('ক্যাশে প্রাপ্ত টাকা যা কোম্পানি/হাব-এ জমা দিতে হবে', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('₹${totalCodCash.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.amber)),
                      ],
                    ),
                  ),

                // Withdrawal Requests History Section
                if (user != null) _buildPayoutHistorySection(user.uid, ref),

                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('সাম্প্রতিক সম্পন্ন করা ডেলিভারি (${orders.length})', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 10),

                // Recent Deliveries List
                orders.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text('এখনো কোনো ডেলিভারি সম্পন্ন হয়নি', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final o = orders[index];
                          final charge = (o['delivery_charge'] ?? 0).toDouble();
                          final deliveredAtStr = o['delivered_at'] as String?;
                          final deliveredAt = deliveredAtStr != null 
                              ? DateTime.tryParse(deliveredAtStr) ?? DateTime.now()
                              : DateTime.now();
                          final dateStr = DateFormat('dd MMM, hh:mm a').format(deliveredAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.softGreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: AppColors.softGreen, size: 18),
                              ),
                              title: Text('অর্ডার #${o['orderId'].toString().substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                              trailing: Text('+₹${charge.toInt()}',
                                  style: const TextStyle(color: AppColors.softGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPayoutHistorySection(String userId, WidgetRef ref) {
    final requestsAsync = ref.watch(userPayoutRequestsProvider(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('উইথড্রয়াল রিকোয়েস্ট হিস্ট্রি ও স্ট্যাটাস', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          requestsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
            data: (requests) {
              if (requests.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Text('এখনো কোনো উইথড্রয়াল রিকোয়েস্ট করা হয়নি', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                );
              }

              return Column(
                children: requests.map((req) {
                  Color statusColor = Colors.orange;
                  String statusText = 'পেন্ডিং ⏳';
                  if (req.status == 'paid') {
                    statusColor = Colors.green;
                    statusText = 'অনুমোদিত ও ব্যাংক/UPI-তে জমা (PAID) ✅';
                  } else if (req.status == 'rejected') {
                    statusColor = Colors.red;
                    statusText = 'বাতিল করা হয়েছে ❌';
                  }

                  final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('উইথড্রয়াল পরিমাণ: ₹${req.amount.toInt()}', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Icon(
                          req.status == 'paid' ? Icons.check_circle_rounded : (req.status == 'rejected' ? Icons.cancel_rounded : Icons.pending_actions_rounded),
                          color: statusColor,
                          size: 24,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleWithdrawal(BuildContext context, WidgetRef ref, double totalEarnings) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final repo = ref.read(payoutRepositoryProvider);
    final bankDetails = await repo.getBankDetails(user.uid);

    if (bankDetails == null) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ব্যাংক ডিটেইলস প্রয়োজন'),
            content: const Text('উইথড্র করার আগে অনুগ্রহ করে আপনার ব্যাংক বা UPI ডিটেইলস সেভ করুন।'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => BankDetailsScreen(userId: user.uid)));
                },
                child: const Text('ব্যাংক/UPI ফর্ম খুলুন'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check existing payout requests
    final requests = ref.read(userPayoutRequestsProvider(user.uid)).value ?? [];
    
    // Block duplicate pending requests
    final hasPending = requests.any((r) => r.status == 'pending');
    if (hasPending) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('আপনার একটি উইথড্রয়াল রিকোয়েস্ট ইতিমধ্যে পেন্ডিং রয়েছে। সেটি সম্পন্ন হওয়া পর্যন্ত অপেক্ষা করুন। ⏳'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Subtract processed/pending payouts
    final double alreadyPaid = requests
        .where((r) => r.status == 'paid')
        .fold<double>(0.0, (sum, r) => sum + r.amount);

    final double withdrawableBalance = (totalEarnings - alreadyPaid).clamp(0.0, totalEarnings);

    if (withdrawableBalance < 100) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('উইথড্র করার জন্য ন্যূনতম ₹১০০ টাকা ব্যালেন্স থাকতে হবে। আপনার বর্তমান উইথড্রযোগ্য ব্যালেন্স: ₹${withdrawableBalance.toInt()}।'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('উইথড্র রিকোয়েস্ট'),
          content: Text('আপনার বর্তমান উইথড্রযোগ্য ব্যালেন্স ₹${withdrawableBalance.toInt()}। আপনি কি এই টাকা পাঠানোর রিকোয়েস্ট করতে চান?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await repo.createPayoutRequest(
                    userId: user.uid,
                    userName: user.name ?? 'Rider',
                    userPhone: user.phone,
                    userType: 'rider',
                    amount: withdrawableBalance,
                    bankDetails: bankDetails,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('উইথড্র রিকোয়েস্ট সফলভাবে অ্যাডমিনের কাছে পাঠানো হয়েছে! ✅'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('সমস্যা হয়েছে: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('হ্যাঁ, রিকোয়েস্ট পাঠান'),
            ),
          ],
        ),
      );
    }
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
