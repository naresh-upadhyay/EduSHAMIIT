import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../config/app_config.dart';

/// Crisp, genuine Scannable QR Code display widget for Gate Passes
class ScannableQrWidget extends StatelessWidget {
  final String passNumber;
  final String? qrBase64;
  final double size;
  final Color backgroundColor;

  const ScannableQrWidget({
    super.key,
    required this.passNumber,
    this.qrBase64,
    this.size = 110,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    // If base64 data URI is provided, use it directly (zero latency)
    if (qrBase64 != null && qrBase64!.isNotEmpty) {
      try {
        final rawBase64 = qrBase64!.contains(',')
            ? qrBase64!.split(',').last
            : qrBase64!;
        final bytes = base64Decode(rawBase64);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          ),
          padding: const EdgeInsets.all(4),
          child: Image.memory(
            bytes,
            width: size - 8,
            height: size - 8,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      } catch (_) {}
    }

    // Otherwise load stream from backend API
    final qrUrl = '${AppConfig.apiBaseUrl}/visitors/gate-passes/$passNumber/qr.png';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Image.network(
        qrUrl,
        width: size - 8,
        height: size - 8,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFF2563EB),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Reliable fallback: QR simulation with scannable barcode aesthetics
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 54, color: Color(0xFF0F172A)),
              const SizedBox(height: 2),
              Text(
                passNumber,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }
}
