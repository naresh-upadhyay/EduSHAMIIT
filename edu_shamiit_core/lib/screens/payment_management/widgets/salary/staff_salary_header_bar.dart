import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/staff_salary_provider.dart';

class StaffSalaryHeaderBar extends ConsumerWidget {
  const StaffSalaryHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availableMonths = state.availableMonths.contains(state.selectedMonthStr)
        ? state.availableMonths
        : [state.selectedMonthStr, ...state.availableMonths];

    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Icon + Title + Subtitle
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF16A34A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Staff Salary Management',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manage staff payroll, base pay structures, monthly disbursals, deductions, and payslips',
                        style: TextStyle(
                          fontSize: 13,
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
          ),
          const SizedBox(width: 16),

          // Right: Payroll Month Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.selectedMonthStr,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: availableMonths.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(m),
                      );
                    }).toList(),
                    onChanged: (newMonth) {
                      if (newMonth != null) {
                        notifier.setMonth(newMonth);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
