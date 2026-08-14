import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/rider_provider.dart';
import 'rider_available_orders_tab.dart';
import 'rider_my_deliveries_tab.dart';
import 'rider_earnings_tab.dart';
import 'rider_profile_screen.dart';
import 'rider_registration_screen.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/notifications/call_notification_service.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/services/foreground_service.dart';

class RiderHomeScreen extends ConsumerStatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  ConsumerState<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends ConsumerState<RiderHomeScreen> {
  int _tabIndex = 0;
  final Set<String> _notifiedRiderOrders = {};
  bool _isOverlayAllowed = true;
  bool _isBatteryIgnored = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    ForegroundService.start();

    // 1. Mandatory ID Sync for Notifications
    final user = ref.read(supabaseUserProvider);
    if (user != null) {
      NotificationService.updateUserSubscriptionId(user.id);
    }

    // 2. Setup UI response for call 'VIEW' action
    CallNotificationService.setViewCallback(() {
      if (mounted) setState(() => _tabIndex = 1);
    });

    // 3. Cold-start action check
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
                  'Order Call আসার জন্য "Display over other apps" এবং "Background Pop-up" অন থাকা জরুরি।',
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
    final profileAsync = ref.watch(myRiderProfileProvider);
    final isOnlineAsync = ref.watch(riderOnlineStatusProvider);
    final authController = ref.read(supabaseAuthControllerProvider);

    // Watch for new available orders (Visual Sync Only)
    ref.listen(availableOrdersProvider, (previous, next) {
      next.whenData((orders) {
        final isOnline = ref.read(riderOnlineStatusProvider).value ?? false;
        if (!isOnline) return;

        final newOrders = orders.where((o) => !_notifiedRiderOrders.contains(o['orderId']));
        for (var order in newOrders) {
          _notifiedRiderOrders.add(order['orderId']);
          // Note: Full call UI is handled by native extension for reliability.
        }
      });
    });

    return profileAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (rider) {
        if (rider == null) return const RiderRegistrationScreen();

        if (rider['status'] == 'pending') {
          return Scaffold(
            appBar: AppBar(
              title: const Text('আবেদন রিভিউ হচ্ছে'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await authController.signOut();
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
                    const Icon(Icons.verified_user_outlined, size: 80, color: Colors.blue),
                    const SizedBox(height: 24),
                    Text(
                      'আপনার রাইডার প্রোফাইলটি যাচাই করা হচ্ছে।',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'অ্যাডমিন আপনার তথ্য এবং এনআইডি যাচাই করে অনুমোদন দিলেই আপনি কাজ শুরু পারবেন। অনুগ্রহ করে কিছুক্ষণ অপেক্ষা করুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => RiderRegistrationScreen(existingData: rider)));
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('তথ্য পরিবর্তন করুন'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (rider['is_active'] == false) {
          return const Scaffold(body: Center(child: Text('আপনার অ্যাকাউন্টটি সাময়িকভাবে বন্ধ রাখা হয়েছে। অ্যাডমিনের সাথে যোগাযোগ করুন।')));
        }

        final tabs = const [RiderAvailableOrdersTab(), RiderMyDeliveriesTab(), RiderEarningsTab()];

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Ziko Partner', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              isOnlineAsync.when(
                data: (isOnline) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    children: [
                      Text(isOnline ? 'অনলাইন' : 'অফলাইন',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOnline ? Colors.white : Colors.white70)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isOnline,
                          activeColor: AppColors.softGreen,
                          activeTrackColor: Colors.white24,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: Colors.white12,
                          onChanged: (val) {
                            final user = ref.read(supabaseUserProvider);
                            if (user != null) {
                              ref.read(riderRepositoryProvider).setOnlineStatus(user.id, val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderProfileScreen()));
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPermissionBanner(),
              Expanded(child: IndexedStack(index: _tabIndex, children: tabs)),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
            child: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              backgroundColor: Colors.white,
              indicatorColor: AppColors.primary.withValues(alpha: 0.1),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'উপলব্ধ'),
                NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'ডেলিভারি'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'আয়'),
              ],
            ),
          ),
        );
      },
    );
  }
}
