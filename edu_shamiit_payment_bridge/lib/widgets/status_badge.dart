import 'package:flutter/material.dart';
import '../core/theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label = customLabel ?? status;

    final s = status.toUpperCase();
    if (s.contains('SUCCESS') || s == 'MATCHED' || s == 'GRANTED' || s == 'CONNECTED' || s == 'UP TO DATE' || s == 'REGISTERED') {
      bg = AppColors.successGreenBg;
      fg = AppColors.successGreen;
      if (customLabel == null && s == 'MATCHED_CANDIDATE') label = 'Matched';
      if (customLabel == null && s == 'VERIFIED_SUCCESS') label = 'Successful';
    } else if (s.contains('UNMATCHED') || s.contains('WARNING') || s.contains('REVIEW')) {
      bg = AppColors.warningOrangeBg;
      fg = AppColors.warningOrange;
      if (customLabel == null && s == 'UNMATCHED') label = 'Unmatched';
      if (customLabel == null && s == 'REVIEW_REQUIRED') label = 'Review Needed';
    } else if (s.contains('PENDING') || s.contains('AWAITING')) {
      bg = AppColors.pendingBlueBg;
      fg = AppColors.pendingBlue;
      if (customLabel == null && s == 'AWAITING_VERIFICATION') label = 'Pending';
      if (customLabel == null && s == 'PENDING') label = 'Pending';
    } else if (s.contains('REFUND')) {
      bg = AppColors.refundPurpleBg;
      fg = AppColors.refundPurple;
      if (customLabel == null && s == 'REFUNDED') label = 'Refunded';
    } else {
      bg = AppColors.ignoredGreyBg;
      fg = AppColors.ignoredGrey;
      if (customLabel == null && s == 'IGNORED') label = 'Ignored';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
