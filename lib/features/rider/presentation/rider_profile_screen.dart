import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../providers/rider_provider.dart';
import '../../../core/theme/app_theme.dart';

class RiderProfileScreen extends ConsumerWidget {
  const RiderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isOnlineAsync = ref.watch(riderOnlineStatusProvider);
    final completedAsync = ref.watch(myCompletedDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('আমার প্রোফাইল'),
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('ইউজার পাওয়া যায়নি'));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 1. Profile Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, size: 50, color: AppColors.primary),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name ?? 'রাইডার নাম',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user.phone,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          completedAsync.when(
                            data: (orders) => _StatItem(label: 'মোট ডেলিভারি', value: '${orders.length}'),
                            loading: () => const _StatItem(label: 'লোড হচ্ছে...', value: '-'),
                            error: (_, __) => const _StatItem(label: 'Error', value: '0'),
                          ),
                          const _StatItem(label: 'রেটিং', value: '4.8 ⭐'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // 2. Status Toggle
                isOnlineAsync.when(
                  data: (isOnline) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.softGreen.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isOnline ? AppColors.softGreen.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.power_settings_new, color: isOnline ? AppColors.softGreen : Colors.red),
                            const SizedBox(width: 12),
                            Text(
                              isOnline ? 'আপনি এখন অনলাইন' : 'আপনি এখন অফলাইন',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOnline ? AppColors.softGreen : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isOnline,
                          activeColor: AppColors.softGreen,
                          onChanged: (val) {
                            ref.read(riderRepositoryProvider).setOnlineStatus(user.uid, val);
                          },
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                
                const SizedBox(height: 25),

                // 3. Menu Options
                _buildMenuOption(context, icon: Icons.history, title: 'ডেলিভারি হিস্ট্রি', onTap: () {}),
                _buildMenuOption(context, icon: Icons.account_balance, title: 'ব্যাংক ডিটেইলস', onTap: () {}),
                _buildMenuOption(context, icon: Icons.help_outline, title: 'সহায়তা কেন্দ্র', onTap: () {}),
                _buildMenuOption(
                  context, 
                  icon: Icons.logout, 
                  title: 'লগআউট', 
                  isDestructive: true, 
                  onTap: () => _showLogoutDialog(context, ref)
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('সমস্যা হয়েছে: $err')),
      ),
    );
  }

  Widget _buildMenuOption(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : AppColors.charcoal,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('লগআউট'),
        content: const Text('আপনি কি নিশ্চিত যে আপনি লগআউট করতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () async {
              await ref.read(supabaseAuthControllerProvider).signOut();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
            child: const Text('হ্যাঁ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
