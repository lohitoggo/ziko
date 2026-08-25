import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/restaurant_owner_provider.dart';
import '../../../core/theme/app_theme.dart';

class BusinessDashboardTab extends ConsumerWidget {
  final String restaurantId;
  final Function(int) onTabChange;
  const BusinessDashboardTab({super.key, required this.restaurantId, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersProvider(restaurantId));
    final itemsAsync = ref.watch(myItemsProvider(restaurantId));

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'বিজনেস ড্যাশবোর্ড',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ordersAsync.when(
              data: (orders) {
                final totalSales = orders
                    .where((o) => o['status'] == 'delivered')
                    .fold(0.0, (sum, o) => sum + (o['total_amount'] ?? 0));
                
                final activeOrders = orders
                    .where((o) => o['status'] != 'delivered' && o['status'] != 'cancelled' && o['status'] != 'rejected')
                    .length;
                
                final now = DateTime.now();
                final todaySales = orders
                    .where((o) {
                      if (o['status'] != 'delivered') return false;
                      final placedAtStr = o['placed_at'];
                      if (placedAtStr == null) return false;
                      final date = DateTime.tryParse(placedAtStr);
                      if (date == null) return false;
                      return date.day == now.day && date.month == now.month && date.year == now.year;
                    })
                    .fold(0.0, (sum, o) => sum + (o['total_amount'] ?? 0));

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => onTabChange(1), // Sales -> Orders History
                            child: _StatCard(
                              title: 'মোট বিক্রি',
                              value: '₹${totalSales.toInt()}',
                              icon: Icons.account_balance_wallet,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: InkWell(
                            onTap: () => onTabChange(1), // Today Sales -> Orders
                            child: _StatCard(
                              title: 'আজকের বিক্রি',
                              value: '₹${todaySales.toInt()}',
                              icon: Icons.today,
                              color: AppColors.softGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => onTabChange(1), // Go to Orders
                            child: _StatCard(
                              title: 'অ্যাক্টিভ অর্ডার',
                              value: '$activeOrders',
                              icon: Icons.shopping_bag,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: itemsAsync.when(
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
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error: $err'),
            ),
            
            const SizedBox(height: 30),
            const Text(
              'সাম্প্রতিক পারফরম্যান্স',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text('বিক্রির গ্রাফ শীঘ্রই আসছে...', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
