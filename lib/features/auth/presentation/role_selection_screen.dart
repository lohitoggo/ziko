import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'profile_setup_screen.dart';
import '../../restaurant/presentation/business_registration_screen.dart';
import '../../rider/presentation/rider_registration_screen.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  bool _isLoading = false;

  void _selectRole(String role) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আপনার সেশন খুঁজে পাওয়া যায়নি, পুনরায় লগইন করুন')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = currentUser.id;
      await ref.read(userRepositoryProvider).updateRole(uid, role);
      
      // Force refresh the profile
      ref.invalidate(currentUserProvider);
      
      if (!mounted) return;

      // Direct Navigation to specific onboarding pages
      switch (role) {
        case 'customer':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
          break;
        case 'restaurant':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BusinessRegistrationScreen()));
          break;
        case 'rider':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderRegistrationScreen()));
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              Text(
                'আপনি কে হিসেবে যুক্ত হতে চান?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'এটা পরে পরিবর্তন করা যাবে না, সঠিকভাবে বাছাই করুন',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 34),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _RoleCard(
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  title: 'গ্রাহক (Customer)',
                  subtitle: 'খাবার অর্ডার করতে চাই',
                  onTap: () => _selectRole('customer'),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.storefront_rounded,
                  color: AppColors.gold,
                  title: 'রেস্টুরেন্ট মালিক',
                  subtitle: 'আমার রেস্টুরেন্ট নিবন্ধন করতে চাই',
                  onTap: () => _selectRole('restaurant'),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  icon: Icons.delivery_dining_rounded,
                  color: AppColors.softGreen,
                  title: 'ডেলিভারি রাইডার',
                  subtitle: 'ডেলিভারি করে আয় করতে চাই',
                  onTap: () => _selectRole('rider'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style:
                      TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 15, color: AppColors.muted.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}