import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'customer_main_shell.dart';
import 'order_tracking_screen.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final bool isSalon;
  final String? category;
  const OrderSuccessScreen({super.key, required this.orderId, this.isSalon = false, this.category});

  @override
  Widget build(BuildContext context) {
    final String cat = category?.toLowerCase() ?? '';
    final bool isGrocery = cat == 'grocery';
    final bool isMeat = cat == 'meat';
    final bool isMedicine = cat == 'medicine';
    final bool isTech = cat == 'electronics' || cat == 'tech';

    final Color primaryColor = isSalon ? const Color(0xFFFFD700) : 
                              (isGrocery ? const Color(0xFF00B251) : 
                              (isMeat ? const Color(0xFFE11D48) : 
                              (isMedicine ? const Color(0xFFFF0844) : 
                              (isTech ? const Color(0xFF662D8C) : AppColors.primary))));

    final bgColor = isSalon ? const Color(0xFF121214) : const Color(0xFFFFF8F4);
    final cardColor = isSalon ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: isSalon ? primaryColor.withValues(alpha: 0.1) : (isGrocery ? Colors.green.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1)),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: isSalon ? primaryColor : (isGrocery || isMeat || isMedicine || isTech ? primaryColor : Colors.green),
                          size: 90,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              Text(
                isSalon ? 'Luxury Booking Confirmed!' : 'Woohoo! Order Placed!',
                style: GoogleFonts.urbanist(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isSalon 
                  ? 'Your appointment has been scheduled. Prepare for a premium experience.' 
                  : 'Your order has been confirmed and is being prepared with love.',
                style: GoogleFonts.urbanist(
                  fontSize: 15,
                  color: isSalon ? Colors.white70 : AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isSalon ? 0.2 : 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      isSalon ? 'BOOKING ID' : 'ORDER ID',
                      style: GoogleFonts.urbanist(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${orderId.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.urbanist(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingScreen(orderId: orderId),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: primaryColor,
                    foregroundColor: isSalon ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 12,
                    shadowColor: primaryColor.withValues(alpha: 0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSalon ? 'VIEW BOOKING STATUS' : 'TRACK MY ORDER',
                        style: GoogleFonts.urbanist(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_searching_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerMainShell()),
                    (route) => false,
                  );
                },
                child: Text(
                  'BACK TO HOME',
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSalon ? Colors.white60 : AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
