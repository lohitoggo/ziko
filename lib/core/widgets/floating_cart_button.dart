import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/customer/providers/cart_provider.dart';
import '../../features/customer/presentation/cart_screen.dart';
import '../../features/customer/providers/business_provider.dart';
import '../theme/app_theme.dart';

class FloatingCartButton extends ConsumerWidget {
  const FloatingCartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartNotifier = ref.watch(cartProvider.notifier);
    final cart = ref.watch(cartProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    
    if (cart.isEmpty) return const SizedBox();

    // --- Dynamic Theme Selection ---
    final isSalon = selectedCat == 'salon';
    final isGrocery = selectedCat == 'grocery';
    final isMeat = selectedCat == 'meat';
    final isMedicine = selectedCat == 'medicine';
    final isTech = selectedCat == 'electronics';

    final Color primaryColor = isSalon 
        ? const Color(0xFFFFD700) 
        : (isGrocery ? const Color(0xFF00B251) 
            : (isMeat ? const Color(0xFFE11D48) 
                : (isMedicine ? const Color(0xFFFF0844)
                    : (isTech ? const Color(0xFF662D8C) : const Color(0xFFF45D27)))));

    final textColor = isSalon ? Colors.black : Colors.white;

    return Padding(
      // Increased bottom padding to clear the Bottom Navigation Bar
      padding: const EdgeInsets.only(bottom: 85), 
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => const CartScreen())
        ),
        backgroundColor: primaryColor,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.shopping_basket_rounded, color: textColor, size: 24),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: isSalon ? Colors.black : Colors.white, shape: BoxShape.circle),
                    child: Text(
                      '${cartNotifier.totalItems}',
                      style: TextStyle(color: isSalon ? primaryColor : primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View Cart', style: GoogleFonts.urbanist(color: isSalon ? Colors.black54 : Colors.white70, fontSize: 12)),
                Text(
                  '₹${cartNotifier.totalAmount.toInt()}',
                  style: GoogleFonts.urbanist(color: textColor, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(width: 30),
            Icon(Icons.arrow_forward_ios_rounded, color: textColor, size: 14),
          ],
        ),
      ),
    );
  }
}
