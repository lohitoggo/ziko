import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

class AdminOrdersTab extends ConsumerWidget {
  const AdminOrdersTab({super.key});

  void _showAssignRiderSheet(
      BuildContext context, WidgetRef ref, String orderId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final ridersAsync = ref.watch(allRidersProvider);
        return ridersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(20), child: Text('সমস্যা: $e')),
          data: (riders) {
            if (riders.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('কোনো রাইডার নিবন্ধিত নেই'),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: riders.length,
              itemBuilder: (context, index) {
                final rider = riders[index];
                return ListTile(
                  leading: const Icon(Icons.delivery_dining),
                  title: Text(rider['name'] ?? rider['phone'] ?? 'রাইডার'),
                  subtitle: Text(rider['phone'] ?? ''),
                  onTap: () async {
                    await ref
                        .read(adminRepositoryProvider)
                        .assignRiderToOrder(orderId, rider['uid']);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersAdminProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('সমস্যা: $e')),
      data: (orders) {
        if (orders.isEmpty) {
          return const Center(child: Text('এখনো কোনো অর্ডার নেই'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderId = order['orderId'];
            final status = order['status'] ?? 'placed';
            final total = (order['totalAmount'] ?? 0).toDouble();
            final hasRider =
                order['riderUid'] != null && order['riderUid'] != '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('অর্ডার #${orderId.toString().substring(0, 8)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Text('₹${total.toInt()}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('স্ট্যাটাস: $status',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (status == 'ready' && !hasRider)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              _showAssignRiderSheet(context, ref, orderId),
                          child: const Text('রাইডার নিয়োগ করুন (ম্যানুয়াল)'),
                        ),
                      )
                    else if (hasRider && status != 'delivered' && status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              _showAssignRiderSheet(context, ref, orderId),
                          child: const Text('রাইডার পরিবর্তন (Re-assign) করুন'),
                        ),
                      ),
                    if (status == 'cancelled' || status == 'rejected')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _processRefundDialog(context, ref, order),
                          icon: const Icon(Icons.currency_rupee_rounded, size: 16),
                          label: const Text('ওয়ালেটে রিফান্ড দিন (Wallet Refund)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _processRefundDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> order) {
    final customerUid = order['customerUid'] ?? order['customer_uid'] ?? order['user_id'];
    final total = (order['totalAmount'] ?? order['total_amount'] ?? 0).toDouble();
    final orderId = order['orderId']?.toString() ?? 'ZK-${order['id']}';

    if (customerUid == null || customerUid.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কাস্টমার আইডি পাওয়া যায়নি')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ওয়ালেটে রিফান্ড প্রদান'),
        content: Text('কাস্টমারের Ziko Wallet-এ ₹${total.toInt()} টাকা রিফান্ড যোগ করতে চান? (অর্ডার: #${orderId.toString().substring(0, 8)})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(walletRepositoryProvider).addCredit(
                  userId: customerUid.toString(),
                  amount: total,
                  title: 'অর্ডার রিফান্ড (Refund)',
                  description: 'অর্ডার #${orderId.toString().substring(0, 8)} ক্যানসলেশন রিফান্ড',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('কাস্টমার ওয়ালেটে সফলভাবে রিফান্ড জমা হয়েছে! ✅'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('রিফান্ড দিন'),
          ),
        ],
      ),
    );
  }
}