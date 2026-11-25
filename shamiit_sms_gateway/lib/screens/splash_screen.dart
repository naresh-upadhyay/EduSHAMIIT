import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
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

  String _statusMessage = 'Initializing SMS Gateway Engine...';
  double _progressValue = 0.2;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
    _startStatusSequence();
    _bootstrap();
  }

  void _startStatusSequence() {
    final steps = [
      {'msg': 'Initializing SMS Gateway Engine...', 'prog': 0.25, 'delay': 300},
      {'msg': 'Discovering Hardware SIM Subscriptions...', 'prog': 0.55, 'delay': 750},
      {'msg': 'Verifying Keystore Security...', 'prog': 0.80, 'delay': 1250},
      {'msg': 'Gateway Terminal Ready', 'prog': 1.0, 'delay': 1700},
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
      if (_isLoggedIn) {
        await PlatformBridge.discoverSims();
      }
    } catch (e) {
      debugPrint('[SplashScreen] Init warning: $e');
      _isLoggedIn = false;
    }

    final elapsed = DateTime.now().difference(startTime);
    const minWait = Duration(milliseconds: 1900);
    if (elapsed < minWait) {
      await Future.delayed(minWait - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) =>
            _isLoggedIn ? const MainNavigationShell() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071530),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.primaryBlue.withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.purple.withValues(alpha: 0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (_, __) => Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: 104,
                            height: 104,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/shamiit_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.sms_rounded,
                                color: AppColors.primaryBlue,
                                size: 52,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'SHAMIIT',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.45)),
                      ),
                      child: const Text(
                        'SMS GATEWAY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      AppConstants.tagline,
                      style: TextStyle(color: Colors.white60, fontSize: 12.5, fontStyle: FontStyle.italic),
                    ),
                    const Spacer(flex: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressValue,
                        minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      AppConstants.companyName,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
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
