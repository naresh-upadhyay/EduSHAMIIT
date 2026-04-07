import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _spinningController;
  late AnimationController _loadingController;
  late Animation<double> _spinningAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    // Set system UI overlay style for splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _spinningController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _spinningAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _spinningController, curve: Curves.linear));
    _spinningController.repeat();
    _loadingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _loadingAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut));
    _loadingController.forward();
    Future.delayed(const Duration(seconds: 2), () { if (mounted) context.go('/login'); });
  }

  @override
  void dispose() { _spinningController.dispose(); _loadingController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo with spinning ring
              AnimatedBuilder(
                animation: _spinningAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SpinningRingPainter(_spinningAnimation.value),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Text('🎓', style: TextStyle(fontSize: 42)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),
              // EduSHAMIIT title with gradient
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Edu',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    TextSpan(
                      text: 'SHAMIIT',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              const Text(
                'AI-Powered School ERP',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0x66FFFFFF),
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 3),
              // Loading bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AnimatedBuilder(
                  animation: _loadingAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _loadingAnimation.value,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class SpinningRingPainter extends CustomPainter {
  final double progress;
  SpinningRingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 + 8;
    
    // Outer ring with gradient
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 6.28318,
      colors: const [
        Color(0xFF4F46E5),
        Color(0xFF06B6D4),
        Color(0xFF4F46E5),
      ],
      stops: const [0.0, 0.5, 1.0],
      transform: GradientRotation(progress * 6.28318),
    );
    paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
    
    // Inner subtle ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.3);
    canvas.drawCircle(center, radius - 4, innerPaint);
  }
  @override
  bool shouldRepaint(covariant SpinningRingPainter oldDelegate) => oldDelegate.progress != progress;
}
