import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../providers/restaurant_owner_provider.dart';
import 'restaurant_orders_tab.dart';
import 'restaurant_menu_tab.dart';
import 'business_dashboard_tab.dart';
import 'business_profile_tab.dart';
import 'business_registration_screen.dart';
import '../../../core/notifications/call_notification_service.dart';
import '../../../core/services/foreground_service.dart';

import 'qr_scanner_screen.dart';
import '../../../core/theme/app_theme.dart';

class RestaurantHomeScreen extends ConsumerStatefulWidget {
  const RestaurantHomeScreen({super.key});

  @override
  ConsumerState<RestaurantHomeScreen> createState() => _RestaurantHomeScreenState();
}

class _RestaurantHomeScreenState extends ConsumerState<RestaurantHomeScreen> {
  int _tabIndex = 0;
  final Set<String> _notifiedOrders = {};
  bool _isOverlayAllowed = true;
  bool _isBatteryIgnored = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    ForegroundService.start();

    // 1. Setup UI response for call 'VIEW' action
    CallNotificationService.setViewCallback(() {
      if (mounted) setState(() => _tabIndex = 1);
    });

    // 2. Cold-start action check
    CallNotificationService.checkPendingOrderAction();
  }

  Future<void> _checkPermissions() async {
    final overlay = await Permission.systemAlertWindow.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _isOverlayAllowed = overlay;
        _isBatteryIgnored = battery;
      });
    }
  }

  Widget _buildPermissionBanner() {
    if (_isOverlayAllowed && _isBatteryIgnored) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade800,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'কল পেতে সেটিংস ঠিক করুন',
                  style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'অর্ডার কল আসার জন্য "Display over other apps" এবং "Background Pop-up" অন থাকা জরুরি।',
                  style: GoogleFonts.urbanist(color: Colors.white.withOpacity(0.9), fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (!_isOverlayAllowed) await Permission.systemAlertWindow.request();
              if (!_isBatteryIgnored) await Permission.ignoreBatteryOptimizations.request();
              _checkPermissions();
            },
            style: TextButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: Text('ENABLE NOW', style: GoogleFonts.urbanist(color: Colors.orange.shade900, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(myRestaurantProvider);

    return restaurantAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('সমস্যা: $e'))),
      data: (restaurant) {
        if (restaurant == null) return const BusinessRegistrationScreen();

        if (restaurant['status'] == 'pending') {
          return Scaffold(
            appBar: AppBar(
              title: const Text('অনুমোদনের অপেক্ষায়'),
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
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    Text(
                      'আপনার দোকানের তথ্য জমা দেওয়া হয়েছে।',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'অ্যাডমিন আপনার তথ্য যাচাই করে অনুমোদন দিলেই আপনি ড্যাশবোর্ড ব্যবহার করতে পারবেন। অনুগ্রহ করে কিছুক্ষণ অপেক্ষা করুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessRegistrationScreen(existingData: restaurant)));
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('তথ্যাদি পরিবর্তন করুন'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (restaurant['status'] == 'suspended') {
          return const Scaffold(body: Center(child: Text('আপনার দোকানটি বর্তমানে স্থগিত করা হয়েছে। অ্যাডমিনের সাথে যোগাযোগ করুন।')));
        }

        final restaurantId = restaurant['restaurantId'];

        final tabs = [
          BusinessDashboardTab(restaurantId: restaurantId, onTabChange: (index) => setState(() => _tabIndex = index)),
          RestaurantOrdersTab(restaurantId: restaurantId),
          RestaurantMenuTab(restaurantId: restaurantId),
          BusinessProfileTab(restaurant: restaurant),
        ];

        final isSalon = restaurant['category'] == 'salon';

        return Scaffold(
          appBar: AppBar(title: Text(restaurant['name'] ?? 'জিকো বিজনেস')),
          body: Column(
            children: [
              _buildPermissionBanner(),
              Expanded(child: IndexedStack(index: _tabIndex, children: tabs)),
            ],
          ),
          floatingActionButton: isSalon ? FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScannerScreen())),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            label: const Text('SCAN PASS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, // MOVED TO LEFT
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'ড্যাশবোর্ড'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'অর্ডার'),
              NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'মেনু'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'প্রোফাইল'),
            ],
          ),
        );
      },
    );
  }
}
