import 'package:flutter/material.dart';
import '../core/theme.dart';

class HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 18);

    final firstControlPoint = Offset(size.width * 0.35, size.height);
    final firstEndPoint = Offset(size.width * 0.65, size.height - 10);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.85, size.height - 20);
    final secondEndPoint = Offset(size.width, size.height - 8);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class AppHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final bool showRunningBadge;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final VoidCallback? onMenuPressed;

  const AppHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.showRunningBadge = false,
    this.actions,
    this.onBackPressed,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: HeaderWaveClipper(),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.headerNavy,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.headerGradientStart,
              AppColors.headerGradientEnd,
            ],
          ),
        ),
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed:
                    onBackPressed ?? () => Navigator.of(context).maybePop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              Builder(
                builder: (headerCtx) => GestureDetector(
                  onTap: onMenuPressed ?? () => Scaffold.of(headerCtx).openDrawer(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/shamiit_logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!showBackButton)
                    const Text(
                      'SHAMIIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      color: showBackButton ? Colors.white : Colors.white70,
                      fontSize: showBackButton ? 18 : 13,
                      fontWeight:
                          showBackButton ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (showRunningBadge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Running',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}
