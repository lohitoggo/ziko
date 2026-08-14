import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/rider_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RiderAvailableOrdersTab extends ConsumerWidget {
  const RiderAvailableOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(availableOrdersProvider);
    final isOnlineAsync = ref.watch(riderOnlineStatusProvider);
    final user = ref.watch(supabaseUserProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        if (!isOnline) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.power_settings_new, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'অর্ডার দেখতে হলে আগে "অনলাইন" হোন',
                  style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }
        return ordersAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('সমস্যা: $e')),
          data: (orders) {
            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('এই মুহূর্তে কোনো অর্ডার নেই', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final commission = (order['delivery_charge'] ?? 0).toDouble();
                final orderId = order['orderId'];
                final businessId = order['business_id'] ?? '';
                final businessAsync = ref.watch(businessProvider(businessId));

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
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: #${orderId.toString().substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              businessAsync.when(
                                data: (b) => Text(b?.name ?? 'দোকান', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                                loading: () => const SizedBox(height: 12, width: 60, child: LinearProgressIndicator()),
                                error: (_, __) => const Text('Error'),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.softGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('₹${commission.toInt()}', 
                                style: const TextStyle(color: AppColors.softGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(order['delivery_address'] ?? 'লোকেশন পাওয়া যায়নি', 
                                  style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                      children: [
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.payment, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'পেমেন্ট: ${order['payment_method'] == 'cod' ? 'ক্যাশ অন ডেলিভারি' : 'অনলাইন (পরিশোধিত)'}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (user != null) {
                                      ref.read(riderRepositoryProvider).acceptOrder(orderId, user.id);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('ডেলিভারি গ্রহণ করুন', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('সমস্যা: $e')),
    );
  }
}
