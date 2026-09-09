import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/user_provider.dart';
import '../providers/restaurant_owner_provider.dart';
import '../../payouts/providers/payout_provider.dart';
import '../../payouts/presentation/bank_details_screen.dart';
import '../../../core/theme/app_theme.dart';

class BusinessDashboardTab extends ConsumerWidget {
  final String? restaurantId;
  final Function(int) onTabChange;

  const BusinessDashboardTab({super.key, this.restaurantId, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBusinessAsync = ref.watch(myRestaurantProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Text(
              'স্বাগতম, ${user?.name ?? 'দোকান মালিক'}! 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              'আপনার ব্যবসার বর্তমান অবস্থা ও অর্ডার তথ্য',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Business Metrics
            myBusinessAsync.when(
              data: (business) {
                final activeResId = restaurantId ?? business?['restaurantId'];
                if (activeResId == null) return const SizedBox();
                final ordersAsync = ref.watch(myOrdersProvider(activeResId));

                double totalSales = 0;
                int pendingCount = 0;
                int totalCount = 0;

                ordersAsync.whenData((orders) {
                  totalCount = orders.length;
                  for (var o in orders) {
                    if (o['status'] == 'delivered') {
                      totalSales += (o['total_amount'] ?? 0).toDouble();
                    }
                    if (o['status'] == 'placed' || o['status'] == 'accepted' || o['status'] == 'preparing') {
                      pendingCount++;
                    }
                  }
                });

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'মোট বিক্রি (Sales)',
                            value: '₹${totalSales.toStringAsFixed(0)}',
                            icon: Icons.account_balance_wallet,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => onTabChange(1), // Go to Orders
                            child: _StatCard(
                              title: 'চলমান অর্ডার',
                              value: '$pendingCount',
                              icon: Icons.pending_actions,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => onTabChange(1), // Go to Orders
                            child: _StatCard(
                              title: 'মোট অর্ডার',
                              value: '$totalCount',
                              icon: Icons.shopping_bag,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ref.watch(myItemsProvider(activeResId)).when(
                            data: (items) => InkWell(
                              onTap: () => onTabChange(2), // Go to Menu
                              child: _StatCard(
                                title: 'মোট আইটেম',
                                value: '${items.length}',
                                icon: Icons.restaurant_menu,
                                color: AppColors.primary,
                              ),
                            ),
                            loading: () => const _StatCardPlaceholder(),
                            error: (_, _) => const _StatCardPlaceholder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Calculate Withdrawable Balance
                    Builder(
                      builder: (context) {
                        final requests = user != null ? (ref.watch(userPayoutRequestsProvider(user.uid)).value ?? []) : [];
                        final double alreadyPaidOrPending = requests
                            .where((r) => r.status == 'pending' || r.status == 'paid')
                            .fold<double>(0.0, (sum, r) => sum + r.amount);

                        final double withdrawableBalance = (totalSales - alreadyPaidOrPending).clamp(0.0, totalSales);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('পে-আউট / উইথড্রয়াল', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('উইথড্রযোগ্য ব্যালেন্স: ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      Text('₹${withdrawableBalance.toInt()}', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 15)),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _handleWithdrawal(context, ref, totalSales),
                                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                                label: const Text('টাকা তুলুন', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Payout History Section
                    if (user != null) _buildPayoutHistorySection(user.uid, ref),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutHistorySection(String userId, WidgetRef ref) {
    final requestsAsync = ref.watch(userPayoutRequestsProvider(userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'উইথড্রয়াল রিকোয়েস্ট হিস্ট্রি ও স্ট্যাটাস',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        requestsAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
          data: (requests) {
            if (requests.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
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
                  statusText = 'অনুমোদিত ও পরিশোধিত (PAID) ✅';
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
    );
  }

  Future<void> _handleWithdrawal(BuildContext context, WidgetRef ref, double totalSales) async {
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
                child: const Text('ব্যাংক ফর্ম খুলুন'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Fetch all existing payout requests for this user
    final requests = ref.read(userPayoutRequestsProvider(user.uid)).value ?? [];
    
    // Check if there is already a pending request
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

    // Subtract already paid/processed payout amounts from totalSales
    final double alreadyPaid = requests
        .where((r) => r.status == 'paid')
        .fold<double>(0.0, (sum, r) => sum + r.amount);

    final double withdrawableBalance = (totalSales - alreadyPaid).clamp(0.0, totalSales);

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
                    userName: user.name ?? 'Restaurant Owner',
                    userPhone: user.phone,
                    userType: 'restaurant',
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatCardPlaceholder extends StatelessWidget {
  const _StatCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
