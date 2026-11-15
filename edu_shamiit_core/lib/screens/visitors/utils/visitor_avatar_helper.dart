import 'dart:convert';
import 'package:flutter/material.dart';

/// Decodes and returns an appropriate [ImageProvider] for visitor photos,
/// safely handling data URIs (`data:image/...;base64,...`), raw base64 strings,
/// and HTTP/HTTPS network URLs without throwing exceptions.
ImageProvider? getVisitorImageProvider(String? photoUrl) {
  if (photoUrl == null) return null;
  final trimmed = photoUrl.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('data:image') || trimmed.startsWith('base64,')) {
    try {
      final base64String = trimmed.contains(',') ? trimmed.split(',').last : trimmed;
      final bytes = base64Decode(base64String.replaceAll(RegExp(r'\s+'), ''));
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }

  // Handle potential raw base64 string
  if (trimmed.length > 100 && !trimmed.contains('/') && !trimmed.contains(' ')) {
    try {
      final bytes = base64Decode(trimmed);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  return NetworkImage(trimmed);
}

/// A standardized visitor avatar that seamlessly displays network URLs,
/// base64 photos, or a fallback letter initial on high-contrast backgrounds.
class VisitorAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final double fontSize;
  final Color? backgroundColor;

  const VisitorAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 16,
    this.fontSize = 12,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = getVisitorImageProvider(photoUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = (name.trim().isNotEmpty) ? name.trim()[0].toUpperCase() : 'V';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? (isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE)),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2563EB),
              ),
            )
          : null,
    );
  }
}
