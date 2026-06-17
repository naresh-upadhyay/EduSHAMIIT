import 'package:flutter/material.dart';

class AiFab extends StatefulWidget {
  final Gradient gradient;
  final VoidCallback onPressed;

  const AiFab({
    super.key,
    required this.gradient,
    required this.onPressed,
  });

  @override
  State<AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<AiFab> {
  static Offset? _savedOffset;
  double? _x;
  double? _y;
  bool _isDragging = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenSize = MediaQuery.sizeOf(context);
      setState(() {
        if (_savedOffset != null) {
          _x = _savedOffset!.dx.clamp(10.0, screenSize.width - 70.0);
          _y = _savedOffset!.dy.clamp(10.0, screenSize.height - 70.0);
        } else {
          _x = screenSize.width - 80.0;
          _y = screenSize.height - 200.0;
        }
      });
      _insertOverlay();
    });
  }

  void _insertOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final scale = _isDragging ? 0.9 : 1.0;
        return Positioned(
          left: _x ?? 0.0,
          top: _y ?? 0.0,
          child: Material(
            color: Colors.transparent,
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 100),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPressed,
                onPanStart: (_) {
                  setState(() {
                    _isDragging = true;
                  });
                  _overlayEntry?.markNeedsBuild();
                },
                onPanUpdate: (details) {
                  final screenSize = MediaQuery.sizeOf(context);
                  setState(() {
                    _x = (_x! + details.delta.dx).clamp(10.0, screenSize.width - 70.0);
                    _y = (_y! + details.delta.dy).clamp(10.0, screenSize.height - 70.0);
                    _savedOffset = Offset(_x!, _y!);
                  });
                  _overlayEntry?.markNeedsBuild();
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                  });
                  _overlayEntry?.markNeedsBuild();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.gradient.colors.first.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}