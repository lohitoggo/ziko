import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../providers/rider_provider.dart';
import '../../payouts/presentation/bank_details_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/upload_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RiderProfileScreen extends ConsumerStatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  ConsumerState<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends ConsumerState<RiderProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(String uid) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final uploadService = ref.read(uploadServiceProvider);
      final repo = ref.read(userRepositoryProvider);
      
      final imageUrl = await uploadService.uploadImage(File(image.path), 'profile_pics');
      
      if (imageUrl != null) {
        await repo.updateProfileImage(uid, imageUrl);
        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('প্রোফাইল ছবি আপডেট করা হয়েছে')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ছবি আপলোড করতে সমস্যা হয়েছে')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      GestureDetector(
                        onTap: _isUploading ? null : () => _pickAndUploadImage(user.uid),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              backgroundImage: user.profileImageUrl != null 
                                ? CachedNetworkImageProvider(user.profileImageUrl!) 
                                : null,
                              child: user.profileImageUrl == null 
                                ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                                : null,
                            ),
                            if (_isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                ),
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
                            error: (_, _) => const _StatItem(label: 'Error', value: '0'),
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
                          activeThumbColor: AppColors.softGreen,
                          onChanged: (val) {
                            ref.read(riderRepositoryProvider).setOnlineStatus(user.uid, val);
                          },
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
                
                const SizedBox(height: 25),

                // 3. Menu Options
                _buildMenuOption(context, icon: Icons.history, title: 'ডেলিভারি হিস্ট্রি', onTap: () {}),
                _buildMenuOption(context, icon: Icons.account_balance, title: 'ব্যাংক ডিটেইলস', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BankDetailsScreen(userId: user.uid)))),
                _buildMenuOption(context, icon: Icons.help_outline, title: 'সহায়তা কেন্দ্র', onTap: () {}),
                _buildMenuOption(context, icon: Icons.privacy_tip_outlined, title: 'প্রাইভেসি পলিসি', onTap: () => _launchUrl('https://zikoapp.online/privacy-policy')),
                _buildMenuOption(context, icon: Icons.description_outlined, title: 'টার্মস অ্যান্ড কন্ডিশনস', onTap: () => _launchUrl('https://zikoapp.online/terms-and-conditions')),
                _buildMenuOption(
                  context, 
                  icon: Icons.logout, 
                  title: 'লগআউট', 
                  isDestructive: true, 
                  onTap: () => _showLogoutDialog(context)
                ),
                _buildMenuOption(
                  context, 
                  icon: Icons.delete_forever, 
                  title: 'অ্যাকাউন্ট ডিলিট করুন', 
                  isDestructive: true, 
                  onTap: () => _showDeleteAccountDialog(context, user.uid)
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

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $urlString')),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context) {
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

  void _showDeleteAccountDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('অ্যাকাউন্ট ডিলিট'),
        content: const Text('আপনি কি নিশ্চিত যে আপনি অ্যাকাউন্ট ডিলিট করতে চান? আপনার স্থায়ী সমস্ত তথ্য মুছে ফেলা হবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('না')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(userRepositoryProvider).deleteAccount(uid);
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('অ্যাকাউন্ট সফলভাবে ডিলিট করা হয়েছে।')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ডিলিট করতে সমস্যা হয়েছে: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('ডিলিট করুন', style: TextStyle(color: Colors.red)),
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
