import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_areas_tab.dart';
import 'admin_shops_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_riders_tab.dart';
import 'admin_customers_tab.dart';
import 'admin_grocery_tab.dart';
import 'admin_payouts_tab.dart';

class _AdminNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _AdminNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tabIndex = 0;

  static const List<_AdminNavDestination> _destinations = [
    _AdminNavDestination(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'ড্যাশবোর্ড'),
    _AdminNavDestination(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'দোকান'),
    _AdminNavDestination(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'অর্ডার'),
    _AdminNavDestination(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet, label: 'পে-আউট'),
    _AdminNavDestination(icon: Icons.shopping_basket_outlined, selectedIcon: Icons.shopping_basket, label: 'গ্রোসারি'),
    _AdminNavDestination(icon: Icons.directions_bike_outlined, selectedIcon: Icons.directions_bike, label: 'রাইডার'),
    _AdminNavDestination(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'কাস্টমার'),
    _AdminNavDestination(icon: Icons.location_on_outlined, selectedIcon: Icons.location_on, label: 'এলাকা'),
    _AdminNavDestination(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'সেটিংস'),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardTab(onTabChange: (index) => setState(() => _tabIndex = index)),
      const AdminShopsTab(),
      const AdminOrdersTab(),
      const AdminPayoutsTab(),
      const AdminGroceryTab(),
      const AdminRidersTab(),
      const AdminCustomersTab(),
      const AdminAreasTab(),
      const AdminSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('জিকো সুপার অ্যাডমিন', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(supabaseAuthControllerProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final dest = _destinations[index];
              final isSelected = _tabIndex == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _tabIndex = index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? dest.selectedIcon : dest.icon,
                          color: isSelected ? AppColors.primary : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dest.label,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.grey.shade800,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
