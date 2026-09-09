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
      bottomNavigationBar: _buildModernFloatingGlassBar(context, ref, activeColor, isSalon),
    );
  }

  Widget _buildModernFloatingGlassBar(BuildContext context, WidgetRef ref, Color activeColor, bool isSalon) {
    final navBgColor = isSalon 
        ? Colors.black.withValues(alpha: 0.25) 
        : Colors.white.withValues(alpha: 0.22);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 65,
            decoration: BoxDecoration(
              color: navBgColor,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isSalon ? 0.2 : 0.04),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: isSalon 
                    ? const Color(0xFF666666).withValues(alpha: 0.3) 
                    : Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSalon 
                ? [const Color(0xFFD4AF37), const Color(0xFFFFD700)] 
                : [activeColor, activeColor.withValues(alpha: 0.85)],
          ) : null,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isActive ? [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                key: ValueKey(isActive),
                color: isActive 
                    ? (isSalon ? Colors.black : Colors.white) 
                    : activeColor.withValues(alpha: 0.7),
                size: 22,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: isActive
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.urbanist(
                            color: isSalon ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
