import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:intl/intl.dart';
import '../../../../services/hr_lookup_helper.dart';
import 'onboarding_detail_drawer.dart';

class OnboardingPipelineDialog extends StatefulWidget {
  final String initialStage;
  final String? initialDepartment;
  final VoidCallback onDataChanged;

  const OnboardingPipelineDialog({
    super.key,
    this.initialStage = 'All',
    this.initialDepartment,
    required this.onDataChanged,
  });

  @override
  State<OnboardingPipelineDialog> createState() => _OnboardingPipelineDialogState();
}

class _OnboardingPipelineDialogState extends State<OnboardingPipelineDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  late String _selectedStage;
  String _selectedDepartment = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  final int _pageSize = 10;

  List<dynamic> _records = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 10,
    'total_records': 0,
    'total_pages': 1,
  };

  final List<String> _stages = [
    'All',
    'Offer Accepted',
    'Document Collection',
    'Orientation',
    'IT Setup',
    'Training',
    'Completed',
  ];

  List<String> _departments = [
    'All',
    ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage.isEmpty ? 'All' : widget.initialStage;
    if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) {
      _selectedDepartment = widget.initialDepartment!;
    }
    HRLookupHelper.instance.getLookupLabels('DEPARTMENT').then((depts) {
      if (mounted && depts.isNotEmpty) {
        setState(() {
          _departments = ['All', ...depts];
        });
      }
    });
    _fetchRecords(page: 1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords({int page = 1}) async {
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
    if (_selectedDepartment != 'All') {
      query['department'] = _selectedDepartment;
    }
    if (_selectedStage != 'All') {
      query['stage'] = _selectedStage;
    }
    if (_selectedStatus != 'All') {
      query['status'] = _selectedStatus;
    }

    try {
      final res = await _api.get('/onboarding/records', query: query, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _records = res['data'] as List<dynamic>? ?? [];
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load onboarding records.';
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

  Future<void> _changeStage(String onboardingId, String currentStage, String candidateName) async {
    String targetStage = currentStage;
    final notesController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Advance Stage: $candidateName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Target Stage *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: targetStage,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: ['Offer Accepted', 'Document Collection', 'Orientation', 'IT Setup', 'Training', 'Completed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => targetStage = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Transition Notes (Optional)',
                  hintText: 'e.g. Document verification completed',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Transition', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && targetStage != currentStage) {
      try {
        final res = await _api.patch('/onboarding/records/$onboardingId/stage', {
          'stage': targetStage,
          'notes': notesController.text.trim(),
        });
        if (res['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stage transitioned to $targetStage'), backgroundColor: const Color(0xFF10B981)),
          );
          _fetchRecords(page: _pagination['page'] ?? 1);
          widget.onDataChanged();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _openDetailDrawer(String onboardingId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'OnboardingDrawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, __) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          child: SizedBox(
            width: 720,
            child: OnboardingDetailDrawer(
              onboardingId: onboardingId,
              onActionCompleted: () {
                _fetchRecords(page: _pagination['page'] ?? 1);
                widget.onDataChanged();
              },
              onClose: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  Color _getStageColor(String? stage) {
    switch (stage) {
      case 'Offer Accepted':
        return const Color(0xFF6366F1);
      case 'Document Collection':
        return const Color(0xFF0EA5E9);
      case 'Orientation':
        return const Color(0xFF10B981);
      case 'IT Setup':
        return const Color(0xFFF59E0B);
      case 'Training':
        return const Color(0xFFEC4899);
      case 'Completed':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF4F46E5)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalRecords = (_pagination['total_records'] as num?)?.toInt() ?? 0;
    final totalPages = (_pagination['total_pages'] as num?)?.toInt() ?? 1;
    final currentPage = (_pagination['page'] as num?)?.toInt() ?? 1;

    final badgeText = _selectedStage != 'All'
        ? '$totalRecords New Joiners ($_selectedStage)'
        : (_selectedDepartment != 'All'
            ? '$totalRecords New Joiners ($_selectedDepartment)'
            : '$totalRecords New Joiners');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.90,
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
                        child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedStage != 'All'
                                        ? 'Onboarding Workspace: $_selectedStage'
                                        : 'All Onboarding Candidates Workspace',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
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
                                    badgeText,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track joiner progression, verify documents, complete IT setup, and manage onboarding milestones.',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
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

            // Toolbar: Search + Stage + Department + Status + Refresh + Reset
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Search Box
                  SizedBox(
                    width: 260,
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search by name, ID, email, designation...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _fetchRecords(page: 1);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Stage Dropdown
                  SizedBox(
                    width: 170,
                    height: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: _stages.contains(_selectedStage) ? _selectedStage : 'All',
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: _stages.map((st) => DropdownMenuItem(
                            value: st,
                            child: Text(st == 'All' ? 'All Stages' : st, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStage = val);
                              _fetchRecords(page: 1);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Department Dropdown
                  SizedBox(
                    width: 150,
                    height: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: _departments.contains(_selectedDepartment) ? _selectedDepartment : 'All',
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: _departments.map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDepartment = val);
                              _fetchRecords(page: 1);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Status Filter Dropdown
                  SizedBox(
                    width: 130,
                    height: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: AppSearchableDropdown<String>.fromMenuItems(
                          value: _selectedStatus,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          items: ['All', 'In Progress', 'Completed', 'Pending']
                              .map((st) => DropdownMenuItem(value: st, child: Text(st == 'All' ? 'All Status' : st)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedStatus = val);
                              _fetchRecords(page: 1);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Refresh',
                    onPressed: () => _fetchRecords(page: currentPage),
                  ),
                  const SizedBox(width: 6),

                  // Reset All Filters Button
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                    tooltip: 'Reset All Filters',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedStage = 'All';
                        _selectedDepartment = 'All';
                        _selectedStatus = 'All';
                      });
                      _fetchRecords(page: 1);
                    },
                  ),
                ],
              ),
            ),

            // Active Filter Tags Bar
            if (_selectedStage != 'All' ||
                _selectedDepartment != 'All' ||
                _selectedStatus != 'All' ||
                _searchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Active Filters:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  if (_selectedStage != 'All')
                    _buildActiveFilterChip('Stage: $_selectedStage', () {
                      setState(() => _selectedStage = 'All');
                      _fetchRecords(page: 1);
                    }),
                  if (_selectedDepartment != 'All')
                    _buildActiveFilterChip('Dept: $_selectedDepartment', () {
                      setState(() => _selectedDepartment = 'All');
                      _fetchRecords(page: 1);
                    }),
                  if (_selectedStatus != 'All')
                    _buildActiveFilterChip('Status: $_selectedStatus', () {
                      setState(() => _selectedStatus = 'All');
                      _fetchRecords(page: 1);
                    }),
                  if (_searchQuery.trim().isNotEmpty)
                    _buildActiveFilterChip('Search: "$_searchQuery"', () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _fetchRecords(page: 1);
                    }),
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedStage = 'All';
                        _selectedDepartment = 'All';
                        _selectedStatus = 'All';
                      });
                      _fetchRecords(page: 1);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Table Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage ?? 'No onboarding records found matching the criteria.',
                                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 850),
                              child: DataTable(
                              columnSpacing: 20,
                              horizontalMargin: 12,
                              headingRowHeight: 42,
                              dataRowMinHeight: 52,
                              dataRowMaxHeight: 58,
                              columns: const [
                                DataColumn(label: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Candidate Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Joining Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              ],
                              rows: _records.map((r) {
                                final stage = r['stage'] ?? 'Offer Accepted';
                                final status = r['status'] ?? 'Pending';
                                final stageColor = _getStageColor(stage);

                                Color statusBg;
                                Color statusFg;
                                if (status == 'Completed') {
                                  statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF10B981);
                                } else if (status == 'In Progress') {
                                  statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFF3B82F6);
                                } else {
                                  statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
                                  statusFg = const Color(0xFFF59E0B);
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        r['onboarding_code'] ?? 'EMP',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                            child: Text(
                                              r['candidate_name'] != null && r['candidate_name'].toString().isNotEmpty
                                                  ? r['candidate_name'][0].toUpperCase()
                                                  : 'E',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            r['candidate_name'] ?? 'New Hire',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(r['department'] ?? 'Academics', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(r['designation'] ?? 'Staff', style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: stageColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(stage, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stageColor)),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r['joining_date'] != null
                                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['joining_date'].toString()))
                                            : 'N/A',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 18),
                                            tooltip: 'View 360 Detail',
                                            onPressed: () => _openDetailDrawer(r['id'].toString()),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.trending_flat_rounded, size: 18, color: Color(0xFF4F46E5)),
                                            tooltip: 'Advance Stage',
                                            onPressed: () => _changeStage(r['id'].toString(), stage, r['candidate_name'] ?? 'Candidate'),
                                          ),
                                        ],
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

            // Pagination Footer
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize + 1} to ${(currentPage * _pageSize).clamp(0, totalRecords)} of $totalRecords new joiners',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: currentPage > 1 ? () => _fetchRecords(page: currentPage - 1) : null,
                    ),
                    Text(
                      '$currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: currentPage < totalPages ? () => _fetchRecords(page: currentPage + 1) : null,
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
