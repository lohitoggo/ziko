import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/data/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/order_provider.dart';
import 'order_history_screen.dart';
import 'saved_addresses_screen.dart';
import 'wishlist_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: userAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) {
          if (userAsync.hasValue) return _buildProfileBody(userAsync.value!, context, ref, ordersAsync);
          return const Center(child: Text('Error loading profile'));
        },
        data: (user) => _buildProfileBody(user, context, ref, ordersAsync),
      ),
    );
  }

  Widget _buildProfileBody(AppUser? user, BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    if (user == null) return const Center(child: Text('User not found'));
    return Column(
      children: [
        // 1. Premium Gradient Header
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 25,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_rounded, size: 35, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name ?? 'Guest User',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      user.phone,
                      style: GoogleFonts.urbanist(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              children: [
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem(
                        label: 'Orders',
                        value: ordersAsync.maybeWhen(data: (o) => o.length.toString(), orElse: () => '0'),
                      ),
                      _vDivider(),
                      _statItem(label: 'Credits', value: '₹0'),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                // Options List
                _profileTile(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Order History',
                  subtitle: 'View your past and current orders',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                ),
                _profileTile(
                  icon: Icons.favorite_outline_rounded,
                  title: 'My Wishlist',
                  subtitle: 'Items you have saved for later',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                ),
                _profileTile(
                  icon: Icons.location_on_outlined,
                  title: 'Saved Addresses',
                  subtitle: 'Manage your delivery locations',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
                ),
                _profileTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'Get assistance with your orders',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                _profileTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out from your account',
                  isDestructive: true,
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statItem({required String label, required String value}) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.charcoal)),
        Text(label, style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _vDivider() => Container(height: 30, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 30));

  Widget _profileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : AppColors.charcoal;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: (isDestructive ? Colors.red : AppColors.primary).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary, size: 22),
        ),
        title: Text(title, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        subtitle: Text(subtitle, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text('Logout', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(supabaseAuthControllerProvider).signOut();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
