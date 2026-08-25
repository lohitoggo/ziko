import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_home_screen.dart';
import 'order_history_screen.dart';
import 'wishlist_screen.dart';
import 'account_screen.dart';
import 'package:google_fonts/google_fonts.dart';

final customerTabControllerProvider = StateProvider<int>((ref) => 0);

class CustomerMainShell extends ConsumerWidget {
  const CustomerMainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(customerTabControllerProvider);

    final List<Widget> pages = [
      const CustomerHomeScreen(),
      const OrderHistoryScreen(),
      const WishlistScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      extendBody: true, // Crucial for the glass effect to show content behind
      body: pages[selectedIndex],
      bottomNavigationBar: _buildModernBottomBar(context, ref),
    );
  }

  Widget _buildModernBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: const Color(0xFFF45D27).withValues(alpha: 0.15), width: 1)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Stronger blur
          child: Container(
            padding: EdgeInsets.only(
              left: 10, right: 10, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              // SUBTLE ORANGE TINT TO MATCH HEADER
              color: const Color(0xFFF45D27).withValues(alpha: 0.08), 
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(ref, 0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(ref, 1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
                _navItem(ref, 2, Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Saved'),
                _navItem(ref, 3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(WidgetRef ref, int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final selectedIndex = ref.watch(customerTabControllerProvider);
    final isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(customerTabControllerProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 18 : 12, vertical: 10),
        decoration: BoxDecoration(
          // GRADIENT PILL TO MATCH HEADER
          gradient: isActive ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
          ) : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFFF45D27).withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? Colors.white : const Color(0xFFF45D27).withValues(alpha: 0.6),
              size: isActive ? 24 : 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.urbanist(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
