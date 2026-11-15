import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visitor_models.dart';
import '../providers/visitors_provider.dart';
import '../utils/visitor_avatar_helper.dart';
import '../../../../utils/js_helper.dart';

class VisitorCategoriesCard extends StatelessWidget {
  final VoidCallback? onManage;

  const VisitorCategoriesCard({super.key, this.onManage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Visitor Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: onManage,
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryBadge('Parent', '42%', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
              _buildCategoryBadge('Official', '18%', const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
              _buildCategoryBadge('Vendor', '12%', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
              _buildCategoryBadge('Maintenance', '10%', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
              _buildCategoryBadge('Alumni', '8%', const Color(0xFFFCE7F3), const Color(0xFFBE185D)),
              _buildCategoryBadge('Relative', '6%', const Color(0xFFCFFAFE), const Color(0xFF0E7490)),
              _buildCategoryBadge('Other', '4%', const Color(0xFFF1F5F9), const Color(0xFF475569)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String label, String pct, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '$label $pct',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}

class LocationBarChartCard extends ConsumerWidget {
  final VoidCallback? onViewAll;
  final Function(String location)? onSelectLocation;

  const LocationBarChartCard({super.key, this.onViewAll, this.onSelectLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);

    // 1. Get raw locations from analytics or fallback to aggregating state.visits
    List<Map<String, dynamic>> rawLocations = List<Map<String, dynamic>>.from(state.analytics.locations);
    if (rawLocations.isEmpty && state.visits.isNotEmpty) {
      final Map<String, int> counts = {};
      for (final v in state.visits) {
        final loc = v.location.trim().isNotEmpty ? v.location : 'Main Gate';
        counts[loc] = (counts[loc] ?? 0) + 1;
      }
      final sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      rawLocations = sortedEntries.take(7).map((e) => {'location': e.key, 'count': e.value}).toList();
    }

    int maxCount = 1;
    for (final loc in rawLocations) {
      final c = (loc['count'] as num?)?.toInt() ?? 0;
      if (c > maxCount) maxCount = c;
    }

    final barColors = [
      const Color(0xFF2563EB),
      const Color(0xFF3B82F6),
      const Color(0xFF06B6D4),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFF94A3B8),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Today's Visitors by Location",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: onViewAll ??
                    () {
                      showDialog(
                        context: context,
                        builder: (ctx) => CampusLocationsBreakdownDialog(
                          locations: rawLocations,
                          onSelectLocation: (loc) {
                            final now = DateTime.now();
                            final todayStart = DateTime(now.year, now.month, now.day);
                            final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                            notifier.setDateRangeFilter('Today', startDate: todayStart, endDate: todayEnd);
                            notifier.setLocationFilter(loc);
                          },
                        ),
                      );
                    },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rawLocations.isEmpty)
            Container(
              height: 70,
              alignment: Alignment.center,
              child: Text(
                'No visits recorded for locations today',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rawLocations.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final loc = entry.value;
                  final label = loc['location']?.toString() ?? 'Location';
                  final count = (loc['count'] as num?)?.toInt() ?? 0;
                  final color = barColors[idx % barColors.length];
                  final height = math.max(12.0, (count / maxCount) * 55.0);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildLocationBar(
                      label: label,
                      count: count,
                      barHeight: height,
                      color: color,
                      isDark: isDark,
                      onTap: () {
                        final now = DateTime.now();
                        final todayStart = DateTime(now.year, now.month, now.day);
                        final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                        notifier.setDateRangeFilter('Today', startDate: todayStart, endDate: todayEnd);
                        notifier.setLocationFilter(label);
                        onSelectLocation?.call(label);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationBar({
    required String label,
    required int count,
    required double barHeight,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: '$label: $count visitors',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: barHeight,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 50,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentVisitorsCard extends ConsumerWidget {
  final VoidCallback? onViewAll;
  final Function(VisitorItem visit)? onSelectVisit;
  final Function(String name)? onSelect;

  const RecentVisitorsCard({super.key, this.onViewAll, this.onSelectVisit, this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);

    // Live recent visits from analytics or state.visits
    final recentAnalytics = state.analytics.recentVisitors;
    final liveVisits = state.visits;

    List<Map<String, dynamic>> items = [];
    if (recentAnalytics.isNotEmpty) {
      items = List<Map<String, dynamic>>.from(recentAnalytics);
    } else if (liveVisits.isNotEmpty) {
      items = liveVisits.take(5).map((v) => {
        'id': v.id,
        'visitor_name': v.visitorName,
        'purpose': v.purpose,
        'destination': v.location,
        'time': _formatTime(v.checkInAt),
        'status': v.status,
        'photo_url': v.photoUrl,
      }).toList();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Visitors',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: onViewAll ??
                    () {
                      showDialog(
                        context: context,
                        builder: (ctx) => RecentVisitorsActivityDialog(
                          items: items,
                          onSelectVisitor: (id) {
                            final match = state.visits.where((v) => v.id == id).firstOrNull;
                            if (match != null) {
                              notifier.openVisitDetail(match);
                            }
                          },
                        ),
                      );
                    },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                'No recent visitor logs found',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            )
          else
            ...items.take(5).map((rv) {
              final id = rv['id']?.toString() ?? '';
              final name = rv['visitor_name']?.toString() ?? 'Visitor';
              final purpose = rv['purpose']?.toString() ?? 'Visit';
              final time = rv['time']?.toString() ?? _formatTime(rv['check_in_at']?.toString());
              final status = rv['status']?.toString() ?? 'Inside';
              final photoUrl = rv['photo_url']?.toString();

              Color statusColor = const Color(0xFF16A34A);
              Color statusBg = const Color(0xFFDCFCE7);
              if (status == 'Inside') {
                statusColor = const Color(0xFF16A34A);
                statusBg = const Color(0xFFDCFCE7);
              } else if (status == 'Overstay') {
                statusColor = const Color(0xFFDC2626);
                statusBg = const Color(0xFFFEE2E2);
              } else if (status == 'Scheduled') {
                statusColor = const Color(0xFF7E22CE);
                statusBg = const Color(0xFFF3E8FF);
              } else {
                statusColor = const Color(0xFF475569);
                statusBg = const Color(0xFFF1F5F9);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildRecentVisitorRow(
                  name: name,
                  purpose: purpose,
                  time: time,
                  status: status,
                  statusColor: statusColor,
                  statusBg: statusBg,
                  photoUrl: photoUrl,
                  isDark: isDark,
                  onTap: () {
                    onSelect?.call(name);
                    final match = liveVisits.firstWhere(
                      (v) => v.id == id || v.visitorName.toLowerCase() == name.toLowerCase(),
                      orElse: () => liveVisits.isNotEmpty ? liveVisits.first : VisitorItem.fromJson(rv),
                    );
                    if (onSelectVisit != null) {
                      onSelectVisit!(match);
                    } else {
                      notifier.openVisitDetail(match);
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    if (raw.contains('AM') || raw.contains('PM')) return raw;
    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${hour.toString().padLeft(2, '0')}:$min $ampm';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildRecentVisitorRow({
    required String name,
    required String purpose,
    required String time,
    required String status,
    required Color statusColor,
    required Color statusBg,
    String? photoUrl,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFDBEAFE),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? getVisitorImageProvider(photoUrl) : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'V',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    purpose,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
              child: Text(
                status,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VisitorsBottomAnalytics extends StatelessWidget {
  const VisitorsBottomAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ExecutiveBriefingCard(),
        SizedBox(height: 16),
        VisitorCategoriesCard(),
        SizedBox(height: 16),
        LocationBarChartCard(),
        SizedBox(height: 16),
        RecentVisitorsCard(),
      ],
    );
  }
}

class CampusLocationsBreakdownDialog extends StatefulWidget {
  final List<dynamic> locations;
  final ValueChanged<String> onSelectLocation;

  const CampusLocationsBreakdownDialog({
    super.key,
    required this.locations,
    required this.onSelectLocation,
  });

  @override
  State<CampusLocationsBreakdownDialog> createState() => _CampusLocationsBreakdownDialogState();
}

class _CampusLocationsBreakdownDialogState extends State<CampusLocationsBreakdownDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalVisits = widget.locations.fold<int>(0, (sum, it) {
      final c = int.tryParse(it['count']?.toString() ?? '0') ?? 0;
      return sum + c;
    });

    final filtered = widget.locations.where((it) {
      if (_search.isEmpty) return true;
      final name = (it['location'] ?? it['destination'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.place_outlined, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Today's Visitors by Location",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$totalVisits total',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Distribution of physical visits across institute gates, offices, and halls',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search campus location (e.g. Main Gate, Library, Lab)...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No location visits match your search.',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final it = filtered[idx];
                        final name = it['location']?.toString() ?? it['destination']?.toString() ?? 'Location';
                        final count = int.tryParse(it['count']?.toString() ?? '0') ?? 0;
                        final percent = totalVisits > 0 ? (count / totalVisits) : 0.0;
                        final color = [
                          const Color(0xFF06B6D4),
                          const Color(0xFFF97316),
                          const Color(0xFFEC4899),
                          const Color(0xFF8B5CF6),
                          const Color(0xFF10B981),
                          const Color(0xFF3B82F6),
                        ][idx % 6];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent.clamp(0.0, 1.0),
                                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                        minHeight: 6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$count visitors',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${(percent * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onSelectLocation(name);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Text('Filter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onSelectLocation('All Locations');
                    },
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reset to All Locations', style: TextStyle(fontSize: 12)),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentVisitorsActivityDialog extends StatefulWidget {
  final List<dynamic> items;
  final ValueChanged<String>? onSelectVisitor;

  const RecentVisitorsActivityDialog({
    super.key,
    required this.items,
    this.onSelectVisitor,
  });

  @override
  State<RecentVisitorsActivityDialog> createState() => _RecentVisitorsActivityDialogState();
}

class _RecentVisitorsActivityDialogState extends State<RecentVisitorsActivityDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = widget.items.where((it) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final name = (it['visitor_name'] ?? '').toString().toLowerCase();
      final purpose = (it['purpose'] ?? '').toString().toLowerCase();
      final status = (it['status'] ?? '').toString().toLowerCase();
      return name.contains(q) || purpose.contains(q) || status.contains(q);
    }).toList();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Visitor Activities Log',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Comprehensive real-time activity log of campus visits and checkouts',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Filter by visitor name, purpose, or status...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No visitor activity records found.',
                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final rv = filtered[idx];
                        final id = rv['id']?.toString() ?? '';
                        final name = rv['visitor_name']?.toString() ?? 'Visitor';
                        final purpose = rv['purpose']?.toString() ?? 'Visit';
                        final time = rv['time']?.toString() ?? rv['check_in_at']?.toString() ?? '-';
                        final status = rv['status']?.toString() ?? 'Inside';
                        final isCompleted = status.toLowerCase() == 'checked out' || status.toLowerCase() == 'completed';

                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            if (widget.onSelectVisitor != null && id.isNotEmpty) {
                              widget.onSelectVisitor!(id);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'V',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB), fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        purpose,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ExecutiveBriefingCard extends ConsumerWidget {
  const ExecutiveBriefingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(visitorsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.assessment_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Executive Audit & PDF',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Board-level summary across all gates, visits & security restrictions',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                final report = await notifier.getExecutiveSummaryReport();
                if (context.mounted) {
                  Navigator.of(context).pop(); // dismiss loading
                  if (report.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (ctx) => ExecutiveSummaryPreviewDialog(report: report),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to generate executive report.')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.white),
              label: const Text('Export Executive Report', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExecutiveSummaryPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> report;

  const ExecutiveSummaryPreviewDialog({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitsKpis = (report['visits_kpis'] as Map<String, dynamic>?) ?? {};
    final scheduledKpis = (report['scheduled_kpis'] as Map<String, dynamic>?) ?? {};
    final blacklistedKpis = (report['blacklisted_kpis'] as Map<String, dynamic>?) ?? {};

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Color(0xFF2563EB), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Executive Security & Visitors Audit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Official Institution Campus Log',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consolidated Executive Key Metrics',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildMetricTile('Inside Campus', '${visitsKpis['active_visitors'] ?? 0}', const Color(0xFF2563EB), isDark),
                        _buildMetricTile('Total Today', '${visitsKpis['total_visitors'] ?? 0}', const Color(0xFF16A34A), isDark),
                        _buildMetricTile('Scheduled Expected', '${scheduledKpis['expected_visitors'] ?? 0}', const Color(0xFF9333EA), isDark),
                        _buildMetricTile('Overstay Alerts', '${visitsKpis['overstay'] ?? 0}', const Color(0xFFDC2626), isDark),
                        _buildMetricTile('Restricted / Flagged', '${blacklistedKpis['total_blacklisted'] ?? 0}', const Color(0xFFB91C1C), isDark),
                        _buildMetricTile('Avg Duration', '${visitsKpis['avg_duration_minutes'] ?? 45} mins', const Color(0xFF0F766E), isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    printExecutiveSummaryHtml(report: report);
                  },
                  icon: const Icon(Icons.print_outlined, size: 16, color: Colors.white),
                  label: const Text('Print / Save PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, Color color, bool isDark) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
