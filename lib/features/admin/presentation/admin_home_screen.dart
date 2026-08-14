import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../providers/admin_provider.dart';
import 'admin_areas_tab.dart';
import 'admin_shops_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_dashboard_tab.dart';
import 'admin_settings_tab.dart';
import 'admin_riders_tab.dart';
import 'admin_customers_tab.dart'; // Added import

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardTab(onTabChange: (index) => setState(() => _tabIndex = index)),
      const AdminShopsTab(),
      const AdminOrdersTab(),
      const AdminRidersTab(),
      const AdminCustomersTab(), // Added Customers tab
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'ড্যাশবোর্ড'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'দোকান'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'অর্ডার'),
          NavigationDestination(icon: Icon(Icons.directions_bike_outlined), selectedIcon: Icon(Icons.directions_bike), label: 'রাইডার'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'কাস্টমার'),
          NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'এলাকা'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'সেটিংস'),
        ],
      ),
    );
  }
}
