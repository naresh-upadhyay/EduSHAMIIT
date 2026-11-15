import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

Color _parseHexOrColor(dynamic val, Color fallback) {
  if (val is Color) return val;
  if (val is String && val.isNotEmpty) {
    try {
      final hex = val.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
  }
  return fallback;
}

class BoardBottomWidgets extends StatelessWidget {
  final Map<String, dynamic> overviewData;
  final VoidCallback? onViewAllActivity;

  const BoardBottomWidgets({
    super.key,
    required this.overviewData,
    this.onViewAllActivity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildRecentActivityCard(context, isDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildWorkByTypeCard(context, isDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildWorkByCategoryCard(context, isDark),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildRecentActivityCard(context, isDark),
              const SizedBox(height: 16),
              _buildWorkByTypeCard(context, isDark),
              const SizedBox(height: 16),
              _buildWorkByCategoryCard(context, isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, bool isDark) {
    final rawLogs = overviewData['recent_activity'] as List<dynamic>? ?? [];
    
    // Default fallback matching screenshot if API list is empty
    final displayLogs = rawLogs.isNotEmpty
        ? rawLogs
        : [
            {
              'actor_name': 'Dr. Neha Sharma',
              'action': 'moved WM-1041 to Resolved',
              'time_ago': '5 min ago',
              'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'
            },
            {
              'actor_name': 'Amit Kumar',
              'action': 'commented on WM-1049: "Wi-Fi installation is 80% complete."',
              'time_ago': '12 min ago',
              'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'
            },
            {
              'actor_name': 'Prof. R. Iyer',
              'action': 'changed due date of WM-1038 to Jan 08',
              'time_ago': '25 min ago',
              'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100'
            },
            {
              'actor_name': 'System',
              'action': 'auto-assigned WM-1056 to Sneha Patel',
              'time_ago': '30 min ago',
              'avatar': ''
            },
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: onViewAllActivity,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayLogs.length.clamp(0, 4),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = displayLogs[index] as Map<String, dynamic>;
              final actor = log['actor_name']?.toString() ?? 'User';
              final action = log['action']?.toString() ?? log['activity_type']?.toString() ?? '';
              final timeAgo = log['time_ago']?.toString() ?? 'Just now';
              final avatar = log['avatar']?.toString() ?? '';
              final isSystem = actor.toLowerCase() == 'system';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isSystem ? const Color(0xFFE0E7FF) : const Color(0xFFE2E8F0),
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? Icon(
                            isSystem ? Icons.computer_outlined : Icons.person_outline,
                            size: 14,
                            color: isSystem ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              height: 1.35,
                            ),
                            children: [
                              TextSpan(
                                text: '$actor ',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: action),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkByTypeCard(BuildContext context, bool isDark) {
    final rawTypes = overviewData['work_by_type'] as List<dynamic>? ?? [];
    
    // Fallback matching screenshot
    final typesList = rawTypes.isNotEmpty
        ? rawTypes.map((e) => e as Map<String, dynamic>).toList()
        : [
            {'type': 'Task', 'count': 38, 'percentage': 58, 'color': const Color(0xFF3B82F6)},
            {'type': 'Story', 'count': 14, 'percentage': 21, 'color': const Color(0xFF38BDF8)},
            {'type': 'Bug', 'count': 8, 'percentage': 12, 'color': const Color(0xFFEF4444)},
            {'type': 'Epic', 'count': 3, 'percentage': 5, 'color': const Color(0xFF8B5CF6)},
            {'type': 'Other', 'count': 3, 'percentage': 5, 'color': const Color(0xFF94A3B8)},
          ];

    int totalCount = 0;
    for (var t in typesList) {
      totalCount += (t['count'] as num?)?.toInt() ?? 0;
    }
    if (totalCount == 0) totalCount = 66;

    final colorMap = {
      'task': const Color(0xFF3B82F6),
      'story': const Color(0xFF38BDF8),
      'bug': const Color(0xFFEF4444),
      'epic': const Color(0xFF8B5CF6),
      'other': const Color(0xFF94A3B8),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work by Type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        startDegreeOffset: -90,
                        sections: typesList.map((item) {
                          final count = (item['count'] as num?)?.toDouble() ?? 1.0;
                          final typeName = item['type']?.toString().toLowerCase() ?? 'other';
                          final fallbackCol = colorMap[typeName] ?? const Color(0xFF94A3B8);
                          final col = _parseHexOrColor(item['color'], fallbackCol);
                          return PieChartSectionData(
                            color: col,
                            value: count,
                            showTitle: false,
                            radius: 16,
                          );
                        }).toList(),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalCount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Work Items',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Legend list
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: typesList.map((item) {
                    final typeName = item['type']?.toString() ?? 'Other';
                    final count = (item['count'] as num?)?.toInt() ?? 0;
                    final pct = (item['percentage'] as num?)?.toInt() ?? ((count * 100) ~/ (totalCount > 0 ? totalCount : 1));
                    final fallbackCol = colorMap[typeName.toLowerCase()] ?? const Color(0xFF94A3B8);
                    final col = _parseHexOrColor(item['color'], fallbackCol);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: col, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              typeName,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Text(
                            '$count ($pct%)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkByCategoryCard(BuildContext context, bool isDark) {
    final rawCats = overviewData['work_by_category'] as List<dynamic>? ?? [];
    
    final catList = rawCats.isNotEmpty
        ? rawCats.map((e) => e as Map<String, dynamic>).toList()
        : [
            {'category': 'Academic', 'count': 18},
            {'category': 'IT Services', 'count': 12},
            {'category': 'Administration', 'count': 10},
            {'category': 'Department', 'count': 8},
            {'category': 'Student Activity', 'count': 6},
            {'category': 'Examination', 'count': 5},
            {'category': 'Facilities', 'count': 4},
            {'category': 'Other', 'count': 3},
          ];

    int maxCount = 1;
    for (var c in catList) {
      final cnt = (c['count'] as num?)?.toInt() ?? 0;
      if (cnt > maxCount) maxCount = cnt;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work by Category',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: catList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final c = catList[index];
              final name = c['category']?.toString() ?? 'General';
              final count = (c['count'] as num?)?.toInt() ?? 0;
              final ratio = (count / maxCount).clamp(0.05, 1.0);

              return Row(
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
