import 'package:flutter/material.dart';

class AiFab extends StatelessWidget {
  final Gradient gradient;
  final VoidCallback onPressed;

  const AiFab({
    super.key,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🤖',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}