import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';

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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}