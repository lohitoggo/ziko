import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';

class AdminDashboardTab extends ConsumerWidget {
  final Function(int) onTabChange;
  const AdminDashboardTab({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(dashboardCountsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'সুপার অ্যাডমিন ড্যাশবোর্ড',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal),
            ),
            const SizedBox(height: 25),

            // 1. Sales Stats
            statsAsync.when(
              data: (stats) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => onTabChange(2), // To Orders
                          child: _StatCard(
                            title: 'মোট বিক্রি',
                            value: '₹${(stats['totalSales'] ?? 0).toInt()}',
                            icon: Icons.account_balance_wallet,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: InkWell(
                          onTap: () => onTabChange(2), // To Orders
                          child: _StatCard(
                            title: 'আজকের বিক্রি',
                            value: '₹${(stats['todaySales'] ?? 0).toInt()}',
                            icon: Icons.today,
                            color: AppColors.softGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () => onTabChange(2), // To Orders
                    child: _StatCard(
                      title: 'বর্তমানে চলমান অর্ডার (Active Orders)',
                      value: '${stats['activeOrders'] ?? 0}',
                      icon: Icons.shopping_bag,
                      color: AppColors.gold,
                      isWide: true,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),

            const SizedBox(height: 25),

            // 2. User/Business Counts
            countsAsync.when(
              data: (counts) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                childAspectRatio: 1.3, // Fixed: Increased aspect ratio to prevent overflow
                children: [
                  InkWell(
                    onTap: () => onTabChange(1), // To Shops
                    child: _StatCard(
                      title: 'মোট দোকান',
                      value: '${counts['restaurants'] ?? 0}',
                      icon: Icons.storefront,
                      color: AppColors.primary,
                    ),
                  ),
                  InkWell(
                    onTap: () => onTabChange(3), // To Riders (was Areas, logic needs fix in HomeScreen)
                    child: _StatCard(
                      title: 'মোট রাইডার',
                      value: '${counts['riders'] ?? 0}',
                      icon: Icons.directions_bike,
                      color: Colors.purple,
                    ),
                  ),
                  _StatCard(
                    title: 'মোট কাস্টমার',
                    value: '${counts['customers'] ?? 0}',
                    icon: Icons.people,
                    color: Colors.teal,
                  ),
                  InkWell(
                    onTap: () => onTabChange(4), // To Areas
                    child: _StatCard(
                      title: 'মোট এরিয়া',
                      value: '${counts['areas'] ?? 0}',
                      icon: Icons.location_on,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),

            const SizedBox(height: 30),
            const Text(
              'সিস্টেম স্ট্যাটাস',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // Maintenance Mode Quick Control (Placeholder for now)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.softGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('আপনার অ্যাপ এখন সচল আছে। সকল ইউজার অর্ডার করতে পারছেন।', 
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
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
  final bool isWide;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isWide ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              if (isWide) Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.charcoal)),
        ],
      ),
    );
  }
}
