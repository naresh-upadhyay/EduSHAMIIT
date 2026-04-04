import 'package:flutter/material.dart';
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
    _spinningController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _spinningAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _spinningController, curve: Curves.linear));
    _spinningController.repeat();
    _loadingController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _loadingAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut));
    _loadingController.forward();
    Future.delayed(const Duration(seconds: 3), () { if (mounted) context.go('/login'); });
  }

  @override
  void dispose() { _spinningController.dispose(); _loadingController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)])),
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            AnimatedBuilder(animation: _spinningAnimation, builder: (context, child) { return CustomPaint(painter: SpinningRingPainter(_spinningAnimation.value), child: const SizedBox(width: 140, height: 140, child: Center(child: Text('🎓', style: TextStyle(fontSize: 70))))); }),
            const SizedBox(height: 48),
            const Text('EduSHAMIIT', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 4),
            ShaderMask(shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]).createShader(bounds), child: const Text('AI', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2))),
            const SizedBox(height: 20),
            const Text('AI-Powered School ERP', style: TextStyle(fontSize: 16, color: Color(0xB3FFFFFF), letterSpacing: 1.5)),
            const Spacer(flex: 3),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 60), child: AnimatedBuilder(animation: _loadingAnimation, builder: (context, child) { return ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: _loadingAnimation.value, minHeight: 6, backgroundColor: Color(0x40FFFFFF), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)))); })),
            const SizedBox(height: 60),
          ]),
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
    final radius = size.width / 2 - 4;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round;
    final gradient = SweepGradient(startAngle: 0, endAngle: 6.28318, colors: const [Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFF4F46E5)], stops: const [0.0, 0.5, 1.0], transform: GradientRotation(progress * 6.28318));
    paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }
  @override
  bool shouldRepaint(covariant SpinningRingPainter oldDelegate) => oldDelegate.progress != progress;
}