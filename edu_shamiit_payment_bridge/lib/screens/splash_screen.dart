import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_navigation_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  String _statusMessage = 'Initializing Ingestion Engine...';
  double _progressValue = 0.15;
  bool _isLoggedIn = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _animController.forward();
    _startStatusSequence();
    _bootstrap();
  }

  void _startStatusSequence() {
    final steps = [
      {'msg': 'Initializing Ingestion Engine...', 'prog': 0.25, 'delay': 400},
      {'msg': 'Securing Hardware Terminal Bridge...', 'prog': 0.50, 'delay': 850},
      {'msg': 'Verifying Enterprise Security...', 'prog': 0.75, 'delay': 1350},
      {'msg': 'Connecting to Banking Telemetry...', 'prog': 0.90, 'delay': 1800},
      {'msg': 'Terminal Ready', 'prog': 1.0, 'delay': 2200},
    ];

    for (final step in steps) {
      Timer(Duration(milliseconds: step['delay'] as int), () {
        if (mounted) {
          setState(() {
            _statusMessage = step['msg'] as String;
            _progressValue = step['prog'] as double;
          });
        }
      });
    }
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();

    try {
      final api = ApiService();
      await api.init();
      _isLoggedIn = await api.isLoggedIn();
    } catch (e) {
      debugPrint('[SplashScreen] Initialization warning: $e');
      _isLoggedIn = false;
    }

    // Ensure smooth presentation by respecting a minimum display window of 2.3 seconds
    final elapsed = DateTime.now().difference(startTime);
    const minWait = Duration(milliseconds: 2300);
    if (elapsed < minWait) {
      await Future.delayed(minWait - elapsed);
    }

    if (!mounted) return;

    // Navigate with seamless fade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _isLoggedIn ? const MainNavigationShell() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030A1C),
      body: Stack(
        children: [
          // Ambient Radial Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryNavy.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Center Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Animated Logo Badge with Glow
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: _glowAnimation.value * 0.4),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(14),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/shamiit_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.account_balance_rounded,
                                    color: AppColors.primaryNavy,
                                    size: 52,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Brand Typography
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const Text(
                            'SHAMIIT',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.5,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'PAYMENT BRIDGE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.0,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Automated Real-Time Ingestion & Reconciliation',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Dynamic Progress & Status Indicator
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B172E).withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Linear Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(begin: 0, end: _progressValue),
                                builder: (context, val, _) => LinearProgressIndicator(
                                  value: val,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFF1E293B),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Animated Status Text
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Row(
                                key: ValueKey<String>(_statusMessage),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _statusMessage,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Enterprise Security & Copyright Footer
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                size: 13,
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Bank-Grade Telemetry • DPDP Act Compliant',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'SHAMIIT Technologies • shamiit.com',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.45),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
