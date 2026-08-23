import 'package:flutter/material.dart';
import '../../../../constants/app_fonts.dart';

class AttendanceConfirmationDialog extends StatelessWidget {
  final String dateStr;
  final String className;
  final String sectionName;
  final String modeName;
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int onLeaveCount;
  final VoidCallback onConfirm;

  const AttendanceConfirmationDialog({
    super.key,
    required this.dateStr,
    required this.className,
    required this.sectionName,
    required this.modeName,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.onLeaveCount,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final isAllDay = modeName.toLowerCase().contains('all day');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: screenWidth < 500 ? double.infinity : 460,
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save Attendance',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sectionName.isNotEmpty ? '$className - $sectionName • $dateStr' : '$className • $dateStr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Responsive Mode Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isAllDay
                        ? (isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF3B0764).withValues(alpha: 0.3) : const Color(0xFFFAF5FF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAllDay
                          ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                          : (isDark ? const Color(0xFF8B5CF6) : const Color(0xFFDDD6FE)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isAllDay ? Icons.lock_outline_rounded : Icons.tune_rounded,
                        color: isAllDay ? const Color(0xFF2563EB) : const Color(0xFF7C3AED),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mode: $modeName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isAllDay ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAllDay
                                  ? 'Locks daily attendance and applies to all scheduled periods.'
                                  : 'Saves attendance across selected periods.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isAllDay
                                    ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6))
                                    : (isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Summary Metric Breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow(
                        'Total Students in Class',
                        totalCount.toString(),
                        isDark ? Colors.white : const Color(0xFF0F172A),
                        isBold: true,
                      ),
                      Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      _buildStatRow('Present', presentCount.toString(), const Color(0xFF10B981)),
                      const SizedBox(height: 6),
                      _buildStatRow('Absent', absentCount.toString(), const Color(0xFFEF4444)),
                      const SizedBox(height: 6),
                      _buildStatRow('Late Entries', lateCount.toString(), const Color(0xFFF59E0B)),
                      const SizedBox(height: 6),
                      _buildStatRow('On Leave', onLeaveCount.toString(), const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                      icon: const Icon(Icons.lock_rounded, size: 15),
                      label: const Text('Confirm & Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? null : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isBold ? 13.5 : 12.5,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
