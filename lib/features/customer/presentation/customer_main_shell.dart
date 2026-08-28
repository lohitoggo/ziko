import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'account_screen.dart';
import 'customer_home_screen.dart';
import '../providers/business_provider.dart';
import 'order_history_screen.dart';
import 'wishlist_screen.dart';
import 'package:google_fonts/google_fonts.dart';

final customerTabControllerProvider = StateProvider<int>((ref) => 0);

class CustomerMainShell extends ConsumerWidget {
  const CustomerMainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(customerTabControllerProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    // --- Dynamic Theme Selection ---
    final isSalon = selectedCat == 'salon';
    final isGrocery = selectedCat == 'grocery';
    final isMeat = selectedCat == 'meat';
    final isMedicine = selectedCat == 'medicine';
    final isTech = selectedCat == 'electronics';

    final Color activeColor = isSalon 
        ? const Color(0xFFFFD700) 
        : (isGrocery ? const Color(0xFF00B251) 
            : (isMeat ? const Color(0xFFE11D48) 
                : (isMedicine ? const Color(0xFFFF0844)
                    : (isTech ? const Color(0xFF662D8C) : const Color(0xFFF45D27)))));

    final List<Widget> pages = [
      const CustomerHomeScreen(),
      const OrderHistoryScreen(),
      const WishlistScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: pages[selectedIndex],
      bottomNavigationBar: _buildModernBottomBar(context, ref, activeColor, isSalon),
    );
  }

  Widget _buildModernBottomBar(BuildContext context, WidgetRef ref, Color activeColor, bool isSalon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: activeColor.withValues(alpha: 0.1), width: 1)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 10, right: 10, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: isSalon ? Colors.black.withValues(alpha: 0.6) : activeColor.withValues(alpha: 0.05), 
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(ref, 0, Icons.home_outlined, Icons.home_rounded, 'Home', activeColor, isSalon),
                _navItem(ref, 1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders', activeColor, isSalon),
                _navItem(ref, 2, Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Saved', activeColor, isSalon),
                _navItem(ref, 3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile', activeColor, isSalon),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(WidgetRef ref, int index, IconData inactiveIcon, IconData activeIcon, String label, Color activeColor, bool isSalon) {
    final selectedIndex = ref.watch(customerTabControllerProvider);
    final isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(customerTabControllerProvider.notifier).state = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
        padding: EdgeInsets.symmetric(horizontal: isActive ? 18 : 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSalon 
                ? [const Color(0xFFD4AF37), const Color(0xFFFFD700)] 
                : [activeColor, activeColor.withValues(alpha: 0.8)],
          ) : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isActive ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.3),
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
              color: isActive ? (isSalon ? Colors.black : Colors.white) : activeColor.withValues(alpha: 0.5),
              size: isActive ? 24 : 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.urbanist(
                  color: isSalon ? Colors.black : Colors.white,
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
