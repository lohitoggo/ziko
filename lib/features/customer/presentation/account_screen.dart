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
import '../../auth/data/phone_auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/upload_provider.dart';
import '../providers/order_provider.dart';
import 'order_history_screen.dart';
import 'saved_addresses_screen.dart';
import 'wishlist_screen.dart';
import '../../support/presentation/support_chat_screen.dart';
import '../../maps/presentation/google_routing_test_screen.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/presentation/wallet_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user.phone,
                      style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    _buildVerificationBadge(user),
                  ],
                ),
              ],
            ),
          ),

          // 2. Stats Section
          Builder(
            builder: (context) {
              final walletAsync = ref.watch(userWalletBalanceProvider(user.uid));
              final walletText = walletAsync.maybeWhen(data: (bal) => '₹${bal.toInt()}', orElse: () => '₹0');

              return Transform.translate(
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
                        _statItem('ZIKO CREDITS', walletText, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(userId: user.uid)))),
                      ],
                    ),
                  ),
                ),
              );
            },
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
                
                // Legal & Policy Pages
                _menuTile(Icons.description_outlined, 'Terms & Conditions', 'Read our terms of service', () => _launchUrl('https://zikoapp.online/terms-and-conditions')),
                _menuTile(Icons.privacy_tip_outlined, 'Privacy Policy', 'How we handle your data', () => _launchUrl('https://zikoapp.online/privacy-policy')),
                _menuTile(Icons.assignment_return_outlined, 'Refund & Cancellation', 'Know our refund policies', () => _launchUrl('https://zikoapp.online/refund-cancellation')),
                _menuTile(Icons.contact_support_outlined, 'Contact Us', 'Get in touch with LK Enterprise', () => _launchUrl('https://zikoapp.online/contact')),

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
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _showDeleteAccountDialog(context, user.uid),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Text('DELETE ACCOUNT', style: GoogleFonts.urbanist(color: Colors.red.shade700, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
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

  Widget _statItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1)),
          ],
        ),
      ),
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
                child: Icon(icon, color: const Color(0xFFF45D27), size: 24),
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

  Widget _buildVerificationBadge(AppUser user) {
    if (user.isPhoneVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade300, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text('VERIFIED', style: GoogleFonts.urbanist(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showVerificationDialog(context, user.phone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 12),
            const SizedBox(width: 4),
            Text('VERIFY NOW', style: GoogleFonts.urbanist(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  void _showVerificationDialog(BuildContext context, String phone) {
    final TextEditingController otpController = TextEditingController();
    final authService = PhoneAuthService(); // Moved outside to persist state
    bool isOtpSent = false;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mobile Verification', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(isOtpSent ? 'Enter 6-digit code sent to $phone' : 'We will send a 6-digit code to $phone', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              if (isOtpSent)
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    if (!isOtpSent) {
                      setModalState(() => isVerifying = true);
                      
                      // Format phone number (Add +91 for India if not present)
                      String formattedPhone = phone.trim();
                      if (!formattedPhone.startsWith('+')) {
                        formattedPhone = '+91$formattedPhone';
                      }

                      await authService.sendOtp(
                        phoneNumber: formattedPhone,
                        onCodeSent: (vid) {
                          setModalState(() {
                            isVerifying = false;
                            isOtpSent = true;
                          });
                        },
                        onError: (error) {
                          setModalState(() => isVerifying = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $error'), backgroundColor: Colors.redAccent)
                            );
                          }
                        },
                      );
                    } else {
                      if (otpController.text.length < 4 && otpController.text.length < 6) return;
                      setModalState(() => isVerifying = true);
                      
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(context);
                      final success = await authService.verifyOtp(otpController.text);
                      if (success) {
                        ref.invalidate(currentUserProvider);
                        messenger.showSnackBar(const SnackBar(content: Text('Mobile number verified successfully! ✅'), backgroundColor: Colors.green));
                        nav.pop();
                      } else {
                        setModalState(() => isVerifying = false);
                        messenger.showSnackBar(const SnackBar(content: Text('Invalid OTP. Please try again.'), backgroundColor: Colors.redAccent));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF45D27), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: isVerifying ? const CircularProgressIndicator(color: Colors.white) : Text(isOtpSent ? 'VERIFY OTP' : 'SEND OTP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
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

  void _showDeleteAccountDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Delete Account?', style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, color: Colors.red.shade700)),
        content: Text('This action is permanent and cannot be undone. All your profile data and saved details will be deleted.', style: GoogleFonts.urbanist(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: GoogleFonts.urbanist(color: Colors.grey, fontWeight: FontWeight.w900))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                await ref.read(userRepositoryProvider).deleteAccount(uid);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthWrapper()), (route) => false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: Text('DELETE', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
