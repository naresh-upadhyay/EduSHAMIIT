import 'package:flutter/material.dart';
import '../core/theme.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final bool showRunningBadge;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  const AppHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.showRunningBadge = false,
    this.actions,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 22,
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
                    'EduSHAMIIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
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
    );
  }
}
