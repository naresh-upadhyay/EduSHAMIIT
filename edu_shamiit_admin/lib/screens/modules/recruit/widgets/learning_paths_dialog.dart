import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class LearningPathsDialog extends StatefulWidget {
  const LearningPathsDialog({super.key});

  @override
  State<LearningPathsDialog> createState() => _LearningPathsDialogState();
}

class _LearningPathsDialogState extends State<LearningPathsDialog> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<dynamic> _paths = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPaths();
  }

  Future<void> _fetchPaths() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/training/learning-paths', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        _paths = res['data'] as List<dynamic>;
      } else {
        _paths = [];
      }
    } catch (_) {
      _paths = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredPaths {
    if (_searchQuery.isEmpty) return _paths;
    return _paths.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final sub = (p['subtitle'] ?? '').toString().toLowerCase();
      final aud = (p['target_audience'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return title.contains(q) || sub.contains(q) || aud.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final list = _filteredPaths;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 860,
        height: 720,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.alt_route_rounded, color: Color(0xFF4F46E5), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Structured Learning Paths & Curriculums',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                        Text(
                          'Multi-course competency roadmaps guiding faculty and staff through sequential professional development.',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search learning paths by title, competency, or audience...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
            const SizedBox(height: 16),

            // List of Paths
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('No learning paths found.'))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, i) {
                            final p = list[i];
                            final title = p['title'] ?? 'Learning Path';
                            final subtitle = p['subtitle'] ?? '';
                            final audience = p['target_audience'] ?? 'All Staff';
                            final total = p['total_courses'] ?? 10;
                            final completed = p['completed_courses'] ?? 5;
                            final pct = (p['progress_percentage'] ?? 50) as int;
                            final enrolled = p['enrolled_count'] ?? 10;
                            final hexStr = p['color_hex'] ?? '#4F46E5';
                            final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));
                            final courses = (p['courses'] as List<dynamic>?) ?? [];

                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.school_rounded, color: color, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                                  ),
                                                  child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text(audience, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                                Icon(Icons.people_outline, size: 14, color: Colors.grey.shade500),
                                                const SizedBox(width: 4),
                                                Text('$enrolled Enrolled Staff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Progress Bar
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct / 100,
                                            minHeight: 6,
                                            color: color,
                                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('$completed/$total Courses ($pct%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                                    ],
                                  ),

                                  // Included Courses Pills
                                  if (courses.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: courses.map((c) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 12, color: color),
                                              const SizedBox(width: 6),
                                              Text('$c', style: const TextStyle(fontSize: 11)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
