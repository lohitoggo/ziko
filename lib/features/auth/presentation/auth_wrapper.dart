import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/supabase_auth_provider.dart';
import '../providers/user_provider.dart';
import '../../admin/providers/admin_provider.dart';
import 'email_login_screen.dart';
import 'onboarding_screen.dart';
import 'role_selection_screen.dart';
import 'area_selection_screen.dart';
import 'calling_readiness_screen.dart';
import '../../customer/presentation/customer_main_shell.dart';
import '../../restaurant/presentation/restaurant_home_screen.dart';
import '../../rider/presentation/rider_home_screen.dart';
import '../../admin/presentation/admin_home_screen.dart';
import '../../customer/presentation/maintenance_screen.dart';
import '../../../core/notifications/notification_service.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to Auth State to trigger rebuilds on login/logout
    final authStateAsync = ref.watch(supabaseAuthStateProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    return authStateAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Auth Connection Error: $err'))),
      data: (state) {
        // ALWAYS check for a physical session to avoid flickering back to login
        final session = Supabase.instance.client.auth.currentSession;
        
        if (session == null) {
          return const EmailLoginScreen();
        }

        // We have a session, handle maintenance and user flow
        return settingsAsync.when(
          skipLoadingOnReload: true,
          data: (settings) {
            final isMaintenance = settings?['is_maintenance_mode'] ?? false;
            final announcement = settings?['announcement'];

            if (isMaintenance) {
              // Only block if NOT an admin
              final userAsync = ref.watch(currentUserProvider);
              return userAsync.when(
                skipLoadingOnReload: true,
                data: (appUser) => (appUser?.role == 'admin') ? _buildMainUI(ref) : MaintenanceScreen(message: announcement),
                loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                error: (_, __) => MaintenanceScreen(message: announcement),
              );
            }

            return _buildMainUI(ref);
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => _buildMainUI(ref), // Proceed to main UI if settings fail
        );
      },
    );
  }

  Widget _buildMainUI(WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 50, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Failed to load profile', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => ref.invalidate(currentUserProvider), child: const Text('Try Again')),
            ],
          ),
        ),
      ),
      data: (appUser) {
        if (appUser == null) {
          // If we have an active session but no profile, wait 2 seconds for DB propagation
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 2)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              // Return Onboarding which now bridges correctly to Role Selection
              return const OnboardingScreen();
            },
          );
        }
        
        // SYNC OneSignal ID (With high reliability)
        if (appUser.uid.isNotEmpty) {
          NotificationService.updateUserSubscriptionId(appUser.uid);
        }

        if (appUser.role.isEmpty) return const RoleSelectionScreen();
        // REMOVED: Mandatory Area Selection screen
        // if (appUser.areaId == null || appUser.areaId!.isEmpty) return const AreaSelectionScreen();
        
        switch (appUser.role) {
          case 'customer': return const CustomerMainShell();
          case 'restaurant': return const CallingReadinessScreen(destination: RestaurantHomeScreen());
          case 'rider': return const CallingReadinessScreen(destination: RiderHomeScreen());
          case 'admin': return const AdminHomeScreen();
          default: return const OnboardingScreen();
        }
      },
    );
  }
}
