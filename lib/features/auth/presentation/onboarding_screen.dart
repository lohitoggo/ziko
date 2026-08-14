import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_wrapper.dart';
import 'role_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Welcome to ziko',
      'subtitle': 'Your Local Super App for Food, Grocery, Medicine, Salon, Parcel & More.',
      'icon': Icons.rocket_launch_rounded,
      'glowColor': Colors.white24,
    },
    {
      'title': 'Everything You Need',
      'subtitle': 'Discover trusted local businesses and get everything delivered to your doorstep.',
      'icons': [Icons.fastfood_rounded, Icons.shopping_basket_rounded, Icons.medical_services_rounded, Icons.content_cut_rounded],
    },
    {
      'title': 'Fast & Reliable Delivery',
      'subtitle': 'Real-time tracking, secure payments and lightning-fast delivery.',
      'icon': Icons.delivery_dining_rounded,
    },
    {
      'title': 'Empower Local Businesses',
      'subtitle': 'Every order supports local entrepreneurs in your community.',
      'icon': Icons.storefront_rounded,
    },
    {
      'title': 'Ready?',
      'subtitle': 'Everything You Need,\nDelivered Faster Than Ever.',
      'isFinal': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Theme Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
            ),
          ),
          
          // Background Sparkles
          _buildTinySparkles(),

          // 2. Page View
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // 3. Bottom Controls
          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) => _buildIndicator(index)),
                ),
                const SizedBox(height: 32),
                
                // Primary Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        // Direct bridge to Role Selection to break the AuthWrapper loop
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectionScreen()));
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFF45D27),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'GET STARTED' : 'CONTINUE',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1),
                    ),
                  ),
                ),
                
                // Skip Button
                if (_currentPage < _pages.length - 1)
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthWrapper())),
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glassmorphic Card
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    if (data['icons'] != null)
                      _buildMultiIcons(data['icons'])
                    else if (data['icon'] != null)
                      Icon(data['icon'], size: 80, color: Colors.white)
                    else
                      const Icon(Icons.check_circle_rounded, size: 80, color: Colors.white),
                    
                    const SizedBox(height: 40),
                    Text(
                      data['title'],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['subtitle'],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 100), // Push content up
        ],
      ),
    );
  }

  Widget _buildMultiIcons(List<IconData> icons) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: icons.map((icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 32),
      )).toList(),
    );
  }

  Widget _buildIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 6,
      width: _currentPage == index ? 24 : 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildTinySparkles() {
    return Positioned.fill(
      child: CustomPaint(
        painter: TinySparklePainter(),
      ),
    );
  }
}

class TinySparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(1);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(Offset(random.nextDouble() * size.width, random.nextDouble() * size.height), random.nextDouble() * 1.5, paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
