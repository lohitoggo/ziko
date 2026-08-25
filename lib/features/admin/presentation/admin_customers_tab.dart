import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminCustomersTab extends ConsumerWidget {
  const AdminCustomersTab({super.key});

  void _showOrderHistory(BuildContext context, WidgetRef ref, String customerUid, String customerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          final historyAsync = ref.watch(customerOrderHistoryProvider(customerUid));
          
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              Text('$customerName - এর অর্ডার হিস্ট্রি', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Expanded(
                child: historyAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) return const Center(child: Text('কোনো অর্ডার পাওয়া যায়নি'));
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final o = orders[index];
                        final date = (o['placedAt'] as dynamic)?.toDate() ?? DateTime.now();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text('অর্ডার #${o['orderId'].toString().substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(date)),
                            trailing: Text('₹${(o['totalAmount'] ?? 0).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) return const Center(child: Text('কোনো কাস্টমার পাওয়া যায়নি'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final c = customers[index];
              final isActive = c['isActive'] ?? true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(c['name'] ?? 'নতুন কাস্টমার', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c['phone'] ?? ''),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showOrderHistory(context, ref, c['uid'], c['name'] ?? 'কাস্টমার'),
                        child: const Text('অর্ডার হিস্ট্রি দেখুন', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(isActive ? 'সক্রিয়' : 'ব্লকড', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: isActive,
                          activeThumbColor: Colors.green,
                          onChanged: (val) {
                            ref.read(adminRepositoryProvider).blockUser(c['uid'], !val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
