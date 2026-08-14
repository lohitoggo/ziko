import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/presentation/email_login_screen.dart';

class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoPulse;
  late Animation<double> _iconOpacity;
  late Animation<double> _loadingWidth;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // 0.0s - 0.5s: Background Fade
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.16, curve: Curves.easeIn)),
    );

    // 0.5s - 1.2s: Logo Scale with Bounce
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.16, 0.4, curve: Curves.elasticOut)),
    );

    // 1.2s - 2.2s: Logo Pulse & Icons
    _logoPulse = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.73, curve: Curves.easeInOut)),
    );
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.6, curve: Curves.easeIn)),
    );

    // 2.2s - 3.0s: Loading Line
    _loadingWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.73, 1.0, curve: Curves.easeInOut)),
    );

    _mainController.forward();

    // Navigation
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF45D27).withValues(alpha: _bgFade.value),
                  const Color(0xFFFF8A00).withValues(alpha: _bgFade.value),
                ],
              ),
            ),
            child: Stack(
              children: [
                _buildGlossyOverlay(),
                _buildSparkles(),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_mainController.value > 0.4)
                        Container(
                          width: 200 * _logoPulse.value,
                          height: 200 * _logoPulse.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ScaleTransition(
                        scale: _logoScale,
                        child: Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 150, height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
                              image: const DecorationImage(image: AssetImage('assets/images/app_icon.png'), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                      if (_mainController.value > 0.4) ...[
                        _buildFloatingIcon(Icons.fastfood_rounded, -100, -100, 0),
                        _buildFloatingIcon(Icons.shopping_cart_rounded, 100, -80, 1),
                        _buildFloatingIcon(Icons.medical_services_rounded, -110, 80, 2),
                        _buildFloatingIcon(Icons.content_cut_rounded, 110, 90, 3),
                        _buildFloatingIcon(Icons.inventory_2_rounded, 0, -130, 4),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  bottom: 100, left: 50, right: 50,
                  child: Column(
                    children: [
                      Container(
                        height: 4, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _loadingWidth.value,
                          child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 10)])),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _loadingWidth,
                        child: Text(
                          'PREPARING YOUR EXPERIENCE...',
                          style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlossyOverlay() {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.1,
        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.transparent, Colors.black]))),
      ),
    );
  }

  Widget _buildSparkles() {
    return Positioned.fill(child: CustomPaint(painter: SparklePainter(progress: _mainController.value)));
  }

  Widget _buildFloatingIcon(IconData icon, double x, double y, int delay) {
    return FadeTransition(
      opacity: _iconOpacity,
      child: Transform.translate(
        offset: Offset(x + 10 * math.sin(_mainController.value * 10 + delay), y + 10 * math.cos(_mainController.value * 8 + delay)),
        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2))), child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

class SparklePainter extends CustomPainter {
  final double progress;
  SparklePainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2;
      canvas.drawCircle(Offset(x, y + (math.sin(progress * 5 + i) * 10)), radius, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
