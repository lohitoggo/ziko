import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/presentation/auth_wrapper.dart';
import '../../auth/data/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/upload_provider.dart';
import '../providers/order_provider.dart';
import 'order_history_screen.dart';
import 'saved_addresses_screen.dart';
import 'wishlist_screen.dart';
import '../../support/presentation/support_chat_screen.dart';
import '../../maps/presentation/google_routing_test_screen.dart';
import 'package:flutter/foundation.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
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
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: userAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF45D27))),
        error: (e, stack) => const Center(child: Text('Error loading profile')),
        data: (user) => _buildLuxuryBody(user, context, ordersAsync),
      ),
    );
  }

  Widget _buildLuxuryBody(AppUser? user, BuildContext context, AsyncValue<List<Map<String, dynamic>>> ordersAsync) {
    if (user == null) return const Center(child: Text('User not found'));
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // 1. Unified Brand Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 30,
              bottom: 50,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isUploading ? null : () => _pickAndUploadImage(user.uid),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: user.profileImageUrl != null 
                              ? CachedNetworkImageProvider(user.profileImageUrl!) 
                              : null,
                          child: user.profileImageUrl == null 
                              ? const Icon(Icons.person_rounded, size: 50, color: Color(0xFFF45D27))
                              : null,
                        ),
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
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Color(0xFFF45D27), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name?.toUpperCase() ?? 'GUEST USER',
                  style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone,
                  style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
          ),

          // 2. Stats Section
          Transform.translate(
            offset: const Offset(0, -25),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statItem('TOTAL ORDERS', ordersAsync.maybeWhen(data: (o) => o.length.toString(), orElse: () => '0')),
                    Container(width: 1, height: 30, color: Colors.grey.shade100),
                    _statItem('ZIKO CREDITS', '₹0.00'),
                  ],
                ),
              ),
            ),
          ),

          // 3. Menu Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _menuTile(Icons.auto_awesome_mosaic_rounded, 'Order History', 'Track and manage your bookings', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()))),
                _menuTile(Icons.favorite_outline_rounded, 'My Wishlist', 'Items you loved the most', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
                _menuTile(Icons.map_outlined, 'Saved Addresses', 'Quick access to your locations', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen()))),
                _menuTile(Icons.help_outline_rounded, 'Help Center', '24/7 Support for your orders', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatScreen()))),
                
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => _showLogoutDialog(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.red.shade100)),
                    alignment: Alignment.center,
                    child: Text('SIGN OUT', style: GoogleFonts.urbanist(color: Colors.red.shade400, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                  ),
                ),

                if (kDebugMode) ...[
                  const SizedBox(height: 30),
                  _menuTile(Icons.terminal_rounded, 'Developer Console', 'Mappls Routing Verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoogleRoutingTestScreen()))),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              Container(
                height: 50, width: 50,
                decoration: BoxDecoration(color: const Color(0xFFF45D27).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Color(0xFFF45D27), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Sign Out?', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.urbanist(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.urbanist(color: Colors.grey, fontWeight: FontWeight.w900))),
          ElevatedButton(
            onPressed: () {
              ref.read(supabaseAuthControllerProvider).signOut();
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthWrapper()), (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: Text('LOGOUT', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
