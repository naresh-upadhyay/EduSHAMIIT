import 'package:flutter/material.dart';

class BoardRightSidebar extends StatelessWidget {
  final Map<String, dynamic> overviewData;
  final Function(String type) onQuickAction;
  final Function(String filter)? onSelectFilter;

  const BoardRightSidebar({
    super.key,
    required this.overviewData,
    required this.onQuickAction,
    this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myWork = overviewData['my_work_summary'] as Map<String, dynamic>? ?? {};
    final kpis = overviewData['kpis'] as Map<String, dynamic>? ?? {};

    final total = (kpis['total'] as num?)?.toInt() ?? 0;
    final newCount = (kpis['new'] as num?)?.toInt() ?? 0;
    final activeCount = (kpis['active'] as num?)?.toInt() ?? 0;
    final resolvedCount = (kpis['resolved'] as num?)?.toInt() ?? 0;
    final completedCount = (kpis['completed'] as num?)?.toInt() ?? 0;

    final newPct = total > 0 ? (newCount * 100 / total).round() : 0;
    final activePct = total > 0 ? (activeCount * 100 / total).round() : 0;
    final resolvedPct = total > 0 ? (resolvedCount * 100 / total).round() : 0;
    final completedPct = total > 0 ? (completedCount * 100 / total).round() : 0;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              _buildQuickActionButton(
                context,
                icon: Icons.assignment_outlined,
                label: 'New Task',
                color: const Color(0xFF3B82F6),
                onTap: () => onQuickAction('TASK'),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.auto_stories_outlined,
                label: 'New Story',
                color: const Color(0xFF8B5CF6),
                onTap: () => onQuickAction('STORY'),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.bug_report_outlined,
                label: 'Report Bug',
                color: const Color(0xFFEF4444),
                onTap: () => onQuickAction('BUG'),
              ),
              _buildQuickActionButton(
                context,
                icon: Icons.military_tech_outlined,
                label: 'New Epic',
                color: const Color(0xFF2563EB),
                onTap: () => onQuickAction('EPIC'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 18),

          // 2. My Work Summary
          Text(
            'My Work Summary',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.person_outline,
            'Assigned to Me',
            '${myWork['assigned_to_me'] ?? 8}',
            isDark,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            Icons.edit_note_outlined,
            'Created by Me',
            '${myWork['created_by_me'] ?? 5}',
            isDark,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            Icons.schedule_outlined,
            'Overdue',
            '${myWork['overdue'] ?? 2}',
            isDark,
            isAlert: true,
          ),
          const SizedBox(height: 10),
          _buildSummaryRow(
            Icons.date_range_outlined,
            'Due This Week',
            '${myWork['due_this_week'] ?? 4}',
            isDark,
          ),
          const SizedBox(height: 22),
          Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 18),

          // 3. Overall Progress
          Text(
            'Overall Progress',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Total Work Items: $total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Multi-segment progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: newCount > 0 ? newCount : 12,
                    child: Container(color: const Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    flex: activeCount > 0 ? activeCount : 18,
                    child: Container(color: const Color(0xFF3B82F6)),
                  ),
                  Expanded(
                    flex: resolvedCount > 0 ? resolvedCount : 9,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  Expanded(
                    flex: completedCount > 0 ? completedCount : 27,
                    child: Container(color: const Color(0xFF8B5CF6)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Breakdown List
          _buildProgressItem('New', newCount, newPct, const Color(0xFF94A3B8), isDark),
          const SizedBox(height: 8),
          _buildProgressItem('Active', activeCount, activePct, const Color(0xFF3B82F6), isDark),
          const SizedBox(height: 8),
          _buildProgressItem('Resolved', resolvedCount, resolvedPct, const Color(0xFF10B981), isDark),
          const SizedBox(height: 8),
          _buildProgressItem('Completed', completedCount, completedPct, const Color(0xFF8B5CF6), isDark),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, bool isDark, {bool isAlert = false}) {
    return InkWell(
      onTap: onSelectFilter != null ? () => onSelectFilter!(label) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isAlert ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, int count, int pct, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
        ),
        Text(
          '$count ($pct%)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
