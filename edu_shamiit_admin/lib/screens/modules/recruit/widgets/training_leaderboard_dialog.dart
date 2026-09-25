import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class TrainingLeaderboardDialog extends StatefulWidget {
  const TrainingLeaderboardDialog({super.key});

  @override
  State<TrainingLeaderboardDialog> createState() => _TrainingLeaderboardDialogState();
}

class _TrainingLeaderboardDialogState extends State<TrainingLeaderboardDialog> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<dynamic> _employees = [];
  Map<String, dynamic> _stats = {};
  String _searchQuery = '';
  String _selectedDept = 'All';
  final List<String> _departments = ['All', 'Academics', 'Administration', 'IT & Technical', 'Finance', 'Transport', 'Teaching'];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final params = <String>[];
      if (_selectedDept != 'All') params.add('department=$_selectedDept');
      if (_searchQuery.isNotEmpty) params.add('search=$_searchQuery');
      final q = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await _api.get('/training/leaderboard$q', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        _employees = res['data'] as List<dynamic>;
        if (res['stats'] is Map) {
          _stats = Map<String, dynamic>.from(res['stats'] as Map);
        }
      } else {
        _employees = [];
      }
    } catch (_) {
      _employees = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredEmployees {
    return _employees.where((e) {
      final name = (e['full_name'] ?? '').toString().toLowerCase();
      final code = (e['employee_code'] ?? '').toString().toLowerCase();
      final dept = (e['department'] ?? '').toString();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || code.contains(_searchQuery.toLowerCase());
      final matchesDept = _selectedDept == 'All' || dept.toLowerCase().contains(_selectedDept.toLowerCase());
      return matchesSearch && matchesDept;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final list = _filteredEmployees;

    // Dynamic stats computation from loaded data / backend
    final totalStaff = _stats['total_evaluated_staff']?.toString() ?? '${_employees.length}';
    final topRate = _stats['top_completion_rate']?.toString() ??
        (_employees.isNotEmpty
            ? '${_employees.map((e) => (e['completion_rate'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b)}%'
            : '0%');
    final avgHrs = _stats['avg_hours_trained']?.toString() ??
        (() {
          final enrolled = _employees.where((e) => ((e['total_enrolled'] as num?)?.toInt() ?? 0) > 0).toList();
          if (enrolled.isEmpty) return '0.0 Hrs';
          final total = enrolled.fold<double>(0.0, (sum, e) => sum + ((e['total_hours'] as num?)?.toDouble() ?? 0.0));
          return '${(total / enrolled.length).toStringAsFixed(1)} Hrs';
        })();
    final leadingDept = _stats['leading_department']?.toString() ??
        (() {
          final deptCounts = <String, int>{};
          for (final e in _employees) {
            final d = (e['department'] ?? 'Academics').toString();
            deptCounts[d] = (deptCounts[d] ?? 0) + ((e['completed_count'] as num?)?.toInt() ?? 0);
          }
          if (deptCounts.isEmpty) return 'Academics';
          var bestDept = 'Academics';
          var maxCount = -1;
          deptCounts.forEach((k, v) {
            if (v > maxCount) {
              maxCount = v;
              bestDept = k;
            }
          });
          return bestDept;
        })();

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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Performing Employees Leaderboard',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                        Text(
                          'Institutional staff training rankings, completion rates, and learning milestones.',
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

            // Top Highlights KPI Strip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildStatTile('Total Evaluated Staff', totalStaff, Icons.groups_outlined, const Color(0xFF4F46E5)),
                  _buildStatTile('Top Completion Rate', topRate, Icons.star_rounded, const Color(0xFF10B981)),
                  _buildStatTile('Avg. Hours Trained', avgHrs, Icons.access_time_rounded, const Color(0xFF0284C7)),
                  _buildStatTile('Leading Department', leadingDept, Icons.school_outlined, const Color(0xFFF59E0B)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search and Filters Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by employee name or ID code...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDept,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedDept = v);
                        _fetchLeaderboard();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Leaderboard Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const Center(child: Text('No employees match the search/filter criteria.'))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final emp = list[i];
                            final rank = i + 1;
                            final name = emp['full_name'] ?? 'Staff Member';
                            final code = emp['employee_code'] ?? 'Emp--';
                            final dept = emp['department'] ?? 'Academics';
                            final desig = emp['designation'] ?? 'Staff';
                            final rate = (emp['completion_rate'] ?? 90) as num;
                            final completed = emp['completed_count'] ?? 0;
                            final hours = emp['total_hours'] ?? 0;
                            final certs = emp['certificates_count'] ?? 0;

                            Widget rankWidget;
                            if (rank == 1) {
                              rankWidget = Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Text('🥇', style: TextStyle(fontSize: 14)),
                              );
                            } else if (rank == 2) {
                              rankWidget = Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Text('🥈', style: TextStyle(fontSize: 14)),
                              );
                            } else if (rank == 3) {
                              rankWidget = Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Color(0xFFFFEDD5), shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const Text('🥉', style: TextStyle(fontSize: 14)),
                              );
                            } else {
                              rankWidget = Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              child: Row(
                                children: [
                                  rankWidget,
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    child: Text(name.isNotEmpty ? name[0] : 'E', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('$code • $desig', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(dept, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$completed Courses • $hours Hrs', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                        Text('$certs Certificates', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: rate / 100,
                                            minHeight: 5,
                                            color: const Color(0xFF10B981),
                                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildStatTile(String label, String val, IconData icon, Color col) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: col, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
