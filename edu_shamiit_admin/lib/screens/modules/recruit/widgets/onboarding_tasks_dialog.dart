import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:intl/intl.dart';

class OnboardingTasksDialog extends StatefulWidget {
  final VoidCallback onDataChanged;

  const OnboardingTasksDialog({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<OnboardingTasksDialog> createState() => _OnboardingTasksDialogState();
}

class _OnboardingTasksDialogState extends State<OnboardingTasksDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final int _pageSize = 15;

  List<dynamic> _tasks = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 15,
    'total_records': 0,
    'total_pages': 1,
  };

  @override
  void initState() {
    super.initState();
    _fetchTasks(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final query = <String, dynamic>{
      'page': page,
      'page_size': _pageSize,
    };

    if (_searchQuery.trim().isNotEmpty) {
      query['search'] = _searchQuery.trim();
    }
    if (_selectedStatus != 'All') {
      query['status'] = _selectedStatus;
    }
    if (_selectedCategory != 'All') {
      query['category'] = _selectedCategory;
    }

    try {
      final res = await _api.get('/onboarding/tasks/all', query: query, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _tasks = res['data'] as List<dynamic>? ?? [];
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load tasks.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTask(String taskId, String currentStatus) async {
    final newStatus = currentStatus == 'Completed' ? 'In Progress' : 'Completed';
    try {
      final res = await _api.patch('/onboarding/tasks/$taskId', {'status': newStatus});
      if (res['success'] == true) {
        _fetchTasks(page: _pagination['page'] ?? 1);
        widget.onDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalRecords = (_pagination['total_records'] as num?)?.toInt() ?? 0;
    final totalPages = (_pagination['total_pages'] as num?)?.toInt() ?? 1;
    final currentPage = (_pagination['page'] as num?)?.toInt() ?? 1;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.checklist_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Onboarding Checklist & Tasks Directory',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$totalRecords Tasks',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track, verify, and complete pre-boarding and onboarding tasks across all institutional departments.',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Toolbar: Search + Status + Category + Refresh
            Row(
              children: [
                // Search
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search task title, code, or candidate name...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _fetchTasks(page: 1);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Status Filter
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: _selectedStatus,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      items: ['All', 'Overdue', 'In Progress', 'Pending', 'Completed']
                          .map((st) => DropdownMenuItem(value: st, child: Text(st == 'All' ? 'All Status' : st)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          _fetchTasks(page: 1);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Category Filter
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<String>.fromMenuItems(
                      value: _selectedCategory,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      items: ['All', 'HR', 'IT', 'Admin', 'Finance', 'General']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Categories' : c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                          _fetchTasks(page: 1);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Refresh Button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () => _fetchTasks(page: currentPage),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Table Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage ?? 'No tasks found matching the criteria.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 800),
                              child: DataTable(
                              columnSpacing: 16,
                              horizontalMargin: 8,
                              headingRowHeight: 40,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 54,
                              columns: const [
                                DataColumn(label: Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Task Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Candidate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Assigned Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: _tasks.map((t) {
                                final status = t['status'] ?? 'Pending';
                                final isCompleted = status == 'Completed';
                                final isOverdue = status == 'Overdue';
                                final priority = t['priority'] ?? 'Medium';

                                Color statusBg;
                                Color statusFg;
                                if (isCompleted) {
                                  statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF10B981);
                                } else if (isOverdue) {
                                  statusBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFFEF4444);
                                } else {
                                  statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF3B82F6);
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: isCompleted,
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (_) => _toggleTask(t['id'].toString(), status),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        t['title'] ?? 'Task',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                          color: isCompleted ? const Color(0xFF94A3B8) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${t['candidate_name'] ?? 'Candidate'} (${t['onboarding_code'] ?? 'EMP'})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(Text(t['category'] ?? 'HR', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(t['assigned_team'] ?? 'HR Team', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      Text(
                                        t['due_date'] != null
                                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(t['due_date'].toString()))
                                            : 'No due date',
                                        style: TextStyle(fontSize: 12, color: isOverdue ? const Color(0xFFEF4444) : null),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: priority == 'High'
                                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          priority,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: priority == 'High' ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
            ),

            // Pagination
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize + 1} to ${(currentPage * _pageSize).clamp(0, totalRecords)} of $totalRecords tasks',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: currentPage > 1 ? () => _fetchTasks(page: currentPage - 1) : null,
                    ),
                    Text(
                      '$currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: currentPage < totalPages ? () => _fetchTasks(page: currentPage + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
