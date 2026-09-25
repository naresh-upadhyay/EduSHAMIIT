import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:intl/intl.dart';

class OnboardingActivityLogDialog extends StatefulWidget {
  const OnboardingActivityLogDialog({super.key});

  @override
  State<OnboardingActivityLogDialog> createState() => _OnboardingActivityLogDialogState();
}

class _OnboardingActivityLogDialogState extends State<OnboardingActivityLogDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedAction = 'All';
  String _searchQuery = '';
  final int _pageSize = 20;

  List<dynamic> _activities = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 20,
    'total_records': 0,
    'total_pages': 1,
  };

  @override
  void initState() {
    super.initState();
    _fetchActivities(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchActivities({int page = 1}) async {
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
    if (_selectedAction != 'All') {
      query['action'] = _selectedAction;
    }

    try {
      final res = await _api.get('/onboarding/activities/all', query: query, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _activities = res['data'] as List<dynamic>? ?? [];
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load activities.';
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

  Color _getActionColor(String? action) {
    switch (action?.toLowerCase()) {
      case 'started':
        return const Color(0xFF6366F1);
      case 'stage changed':
        return const Color(0xFF0EA5E9);
      case 'document verified':
      case 'onboarding completed':
      case 'task completed':
        return const Color(0xFF10B981);
      case 'document rejected':
        return const Color(0xFFEF4444);
      case 'document uploaded':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFFF59E0B);
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
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
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
                        child: const Icon(Icons.history_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Onboarding Activity Audit Log',
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
                                    '$totalRecords Events',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Complete immutable audit history of candidate stage transitions, document verifications, and compliance milestones.',
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

            // Toolbar: Search + Action Filter + Refresh
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search description, action, or user name...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _fetchActivities(page: 1);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Action Filter
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAction,
                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      items: [
                        'All',
                        'Started',
                        'Stage Changed',
                        'Status Changed',
                        'Document Verified',
                        'Document Rejected',
                        'Document Uploaded',
                        'Task Created',
                        'Task Completed',
                        'Onboarding Completed'
                      ].map((a) => DropdownMenuItem(value: a, child: Text(a == 'All' ? 'All Actions' : a))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedAction = val);
                          _fetchActivities(page: 1);
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
                  onPressed: () => _fetchActivities(page: currentPage),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Table Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _activities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_toggle_off_rounded, size: 44, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                _errorMessage ?? 'No activity log records found matching the criteria.',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _activities.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          itemBuilder: (ctx, idx) {
                            final a = _activities[idx];
                            final action = a['action']?.toString() ?? 'Event';
                            final desc = a['description']?.toString() ?? '';
                            final userName = a['user_name']?.toString() ?? 'System HR';
                            final createdAt = a['created_at'] != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(a['created_at'].toString()))
                                : 'Recent';
                            final actionColor = _getActionColor(action);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: actionColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      action,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actionColor),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          desc,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Performed by $userName',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    createdAt,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            // Pagination
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize + 1} to ${(currentPage * _pageSize).clamp(0, totalRecords)} of $totalRecords events',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: currentPage > 1 ? () => _fetchActivities(page: currentPage - 1) : null,
                    ),
                    Text(
                      '$currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: currentPage < totalPages ? () => _fetchActivities(page: currentPage + 1) : null,
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
