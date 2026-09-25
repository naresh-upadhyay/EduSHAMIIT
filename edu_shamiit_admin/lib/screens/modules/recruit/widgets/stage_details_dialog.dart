import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'candidate_detail_drawer.dart';
import 'schedule_interview_dialog.dart';
import 'stage_progression_dialog.dart';

class StageDetailsDialog extends StatefulWidget {
  final String stage;
  final int candidateCount;
  final String? jobId;
  final String? jobTitle;
  final String? jobCode;
  final String? initialDepartment;
  final VoidCallback onDataChanged;

  const StageDetailsDialog({
    super.key,
    required this.stage,
    this.candidateCount = 0,
    this.jobId,
    this.jobTitle,
    this.jobCode,
    this.initialDepartment,
    required this.onDataChanged,
  });

  @override
  State<StageDetailsDialog> createState() => _StageDetailsDialogState();
}

class _StageDetailsDialogState extends State<StageDetailsDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  late String _selectedStage;
  int _pageSize = 10;
  List<dynamic> _candidates = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 10,
    'total_records': 0,
    'total_pages': 1
  };

  static const String _currentSubtab = 'all';
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  String _selectedPosition = 'All';
  String _selectedSource = 'All';

  final Set<String> _selectedCandidateIds = {};
  bool _selectAll = false;

  final TextEditingController _searchController = TextEditingController();

  List<String> _stages = ['All', ...HRLookupHelper.instance.getCachedLabels('RECRUITMENT_STAGE')];
  List<String> _departments = [
    'All',
    'IT',
    'Teaching',
    'Administration',
    'Academics',
    'Mathematics',
    'Transport',
    'Finance',
    ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT'),
  ];
  List<String> _positions = ['All'];
  List<String> _sources = ['All', ...HRLookupHelper.instance.getCachedLabels('RECRUITMENT_SOURCE')];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    final rawStage = widget.stage.trim();
    final normalizedStage = rawStage.toLowerCase() == 'selected candidates' ? 'Selected' : rawStage;
    _selectedStage = (normalizedStage.isNotEmpty && normalizedStage.toLowerCase() != 'applied')
        ? normalizedStage
        : (widget.jobId != null ? 'All' : (normalizedStage.isEmpty ? 'All' : normalizedStage));
    if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) {
      _selectedDepartment = widget.initialDepartment!;
      if (!_departments.contains(_selectedDepartment)) {
        _departments.add(_selectedDepartment);
      }
    }
    _loadLookups(true);
    _fetchStageData();
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final stages = await HRLookupHelper.instance.getLookupLabels('RECRUITMENT_STAGE', forceRefresh: forceRefresh);
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final sources = await HRLookupHelper.instance.getLookupLabels('RECRUITMENT_SOURCE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _stages = ['All', ...stages];
        if (!_stages.contains(_selectedStage)) {
          _selectedStage = 'All';
        }

        final Set<String> deptSet = {
          'All',
          'IT',
          'Teaching',
          'Administration',
          'Academics',
          'Mathematics',
          'Transport',
          'Finance',
          if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) widget.initialDepartment!,
          if (_selectedDepartment.isNotEmpty) _selectedDepartment,
          ...depts,
        };
        _departments = deptSet.toList();

        _sources = ['All', ...sources];
        if (!_sources.contains(_selectedSource)) {
          _selectedSource = 'All';
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _searchController.dispose();
    super.dispose();
  }

  Color _getStageColor(String? stage) {
    switch (stage?.toLowerCase()) {
      case 'applied':
        return const Color(0xFF6366F1);
      case 'screening':
        return const Color(0xFF0284C7);
      case 'shortlisted':
        return const Color(0xFF0D9488);
      case 'assessment':
        return const Color(0xFF8B5CF6);
      case 'selected':
      case 'selected candidates':
        return const Color(0xFFF59E0B);
      case 'interview':
        return const Color(0xFFEC4899);
      case 'offer':
        return const Color(0xFF10B981);
      case 'hired':
        return const Color(0xFF059669);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _fetchStageData({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = {
        'subtab': _currentSubtab,
        'page': page,
        'page_size': _pageSize,
      };
      if (widget.jobId != null && widget.jobId!.isNotEmpty) {
        queryParams['job_id'] = widget.jobId!;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }
      if (_selectedDepartment != 'All') {
        queryParams['department'] = _selectedDepartment;
      }
      if (_selectedPosition != 'All') {
        queryParams['position'] = _selectedPosition;
      }
      if (_selectedSource != 'All') {
        queryParams['source'] = _selectedSource;
      }

      final stageToFetch = _selectedStage.isEmpty ? 'All' : _selectedStage;
      final res = await _api.get(
        '/recruitment/pipeline/$stageToFetch',
        query: queryParams,
        useCache: false,
      );

      if (res['success'] == true) {
        final List<dynamic> loadedCandidates = res['data'] as List<dynamic>? ?? [];
        final Set<String> posSet = {'All'};
        for (final c in loadedCandidates) {
          final p = (c['job_title'] ?? '').toString().trim();
          if (p.isNotEmpty) posSet.add(p);
        }
        if (_selectedPosition != 'All') {
          posSet.add(_selectedPosition);
        }

        setState(() {
          _candidates = loadedCandidates;
          _positions = posSet.toList();
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoading = false;
          _selectedCandidateIds.clear();
          _selectAll = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load stage candidates.';
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

  Future<void> _moveStage(String applicationId, String targetStage, {String? notes}) async {
    try {
      final res = await _api.post(
        '/recruitment/applications/$applicationId/move-stage',
        {'to_stage': targetStage, 'notes': notes ?? 'Moved via Stage Workspace'},
      );
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Candidate successfully moved to $targetStage'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchStageData(page: _pagination['page'] ?? 1);
        widget.onDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openStageProgressionDialogFor(Map<String, dynamic> cand) {
    final appId = cand['application_id']?.toString() ?? '';
    final candidateStage = cand['current_stage']?.toString() ?? widget.stage;
    showDialog(
      context: context,
      builder: (ctx) => StageProgressionDialog(
        applicationId: appId,
        candidateName: cand['full_name'] ?? '',
        candidateCode: cand['candidate_code'],
        jobTitle: cand['job_title'] ?? widget.jobTitle,
        currentStage: candidateStage,
        onConfirm: (targetStage, notes, notifyCandidate) async {
          await _moveStage(appId, targetStage, notes: notes);
        },
      ),
    );
  }

  Future<void> _rejectApplication(String applicationId) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to reject this candidate application?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Qualification mismatch, Failed assessment...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _api.post(
          '/recruitment/applications/$applicationId/reject',
          {'reason': reasonController.text.trim().isEmpty ? 'Not selected' : reasonController.text.trim()},
        );
        if (res['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Candidate application marked as Rejected'), backgroundColor: Color(0xFFEF4444)),
          );
          _fetchStageData(page: _pagination['page'] ?? 1);
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

  Future<void> _executeBulkAction(String action, {String? targetStage}) async {
    if (_selectedCandidateIds.isEmpty) return;
    try {
      final res = await _api.post(
        '/recruitment/candidates/bulk-action',
        {
          'candidate_ids': _selectedCandidateIds.toList(),
          'action': action,
          if (targetStage != null) 'target_stage': targetStage,
        },
      );
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Bulk action executed'), backgroundColor: const Color(0xFF10B981)),
        );
        _fetchStageData(page: _pagination['page'] ?? 1);
        widget.onDataChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _openCandidateDrawer(String candidateId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CandidateDrawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, __) => CandidateDetailDrawer(
        candidateId: candidateId,
        onActionCompleted: () {
          _fetchStageData(page: _pagination['page'] ?? 1);
          widget.onDataChanged();
        },
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recordsInPagination = _pagination['total_records'] as int? ?? 0;
    final totalRecords = _isLoading && recordsInPagination == 0 ? widget.candidateCount : recordsInPagination;
    final totalPages = _pagination['total_pages'] as int? ?? 1;
    final currentPage = _pagination['page'] as int? ?? 1;
    final badgeText = widget.jobTitle != null
        ? (_selectedStage.toLowerCase() == 'all'
            ? '$totalRecords Applicants'
            : '$totalRecords Applicants ($_selectedStage)')
        : (_selectedDepartment != 'All'
            ? '$totalRecords Candidates ($_selectedDepartment)'
            : '$totalRecords Candidates');

    String subtitleText = 'Candidate pipeline management, progression workflows, evaluation & bulk actions.';
    if (widget.jobTitle != null) {
      subtitleText = 'Viewing candidates who specifically applied for this job opening (${widget.jobCode ?? ''}).';
    } else if (_selectedDepartment != 'All' && _selectedPosition != 'All') {
      subtitleText = 'Filtered by Department: $_selectedDepartment • Position: $_selectedPosition';
    } else if (_selectedDepartment != 'All') {
      subtitleText = 'Filtered by Department: $_selectedDepartment';
    } else if (_selectedPosition != 'All') {
      subtitleText = 'Filtered by Position: $_selectedPosition';
    } else if (_selectedStage != 'All') {
      subtitleText = 'Filtered by Stage: $_selectedStage';
    }

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
            // Top Modal Header
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
                        child: const Icon(Icons.filter_alt_outlined, color: Color(0xFF4F46E5), size: 24),
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
                                    widget.jobTitle != null
                                        ? 'Applicants: ${widget.jobTitle}'
                                        : _selectedStage.toLowerCase() == 'all'
                                            ? 'All Candidates Workspace'
                                            : (_selectedStage.toLowerCase() == 'selected' || _selectedStage.toLowerCase() == 'selected candidates')
                                                ? 'Stage Workspace: Selected Candidates'
                                                : 'Stage Workspace: $_selectedStage',
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
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
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
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Filter Bar Row (Search + Stage + Department + Source)
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
                      hintText: 'Search candidate by name, email, code...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    onChanged: (val) {
                      _searchQuery = val;
                      _fetchStageData(page: 1);
                    },
                    onSubmitted: (_) {
                      _fetchStageData(page: 1);
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Stage Filter Dropdown
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
                      child: DropdownButton<String>(
                        value: _stages.contains(_selectedStage) ? _selectedStage : 'All',
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: _stages.map((st) => DropdownMenuItem(
                          value: st,
                          child: Text(
                            st == 'All' ? 'All Stages' : (st == 'Selected' ? 'Selected Candidates' : st),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStage = val);
                            _fetchStageData(page: 1);
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
                      child: DropdownButton<String>(
                        value: _departments.contains(_selectedDepartment) ? _selectedDepartment : 'All',
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: _departments.map((dept) => DropdownMenuItem(
                          value: dept,
                          child: Text(
                            dept,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDepartment = val);
                            _fetchStageData(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Source Filter Dropdown
                SizedBox(
                  width: 140,
                  height: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sources.contains(_selectedSource) ? _selectedSource : 'All',
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: _sources.map((src) => DropdownMenuItem(
                          value: src,
                          child: Text(
                            src,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSource = val);
                            _fetchStageData(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Position / Job Title Dropdown
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
                      child: DropdownButton<String>(
                        value: _positions.contains(_selectedPosition) ? _selectedPosition : 'All',
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: _positions.map((pos) => DropdownMenuItem(
                          value: pos,
                          child: Text(
                            pos == 'All' ? 'All Roles' : pos,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPosition = val);
                            _fetchStageData(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Refresh Button
                SizedBox(
                  width: 38,
                  height: 38,
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () => _fetchStageData(page: _pagination['page'] ?? 1),
                    tooltip: 'Refresh',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Reset Filters Button
                SizedBox(
                  width: 38,
                  height: 38,
                  child: IconButton(
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedStage = 'All';
                        _selectedDepartment = 'All';
                        _selectedPosition = 'All';
                        _selectedSource = 'All';
                      });
                      _fetchStageData(page: 1);
                    },
                    tooltip: 'Reset All Filters',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Filter Tags Bar
          if (_selectedStage != 'All' ||
              _selectedDepartment != 'All' ||
              _selectedPosition != 'All' ||
              _selectedSource != 'All' ||
              _searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Active Filters:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                if (_selectedDepartment != 'All')
                  _buildActiveFilterChip('Dept: $_selectedDepartment', () {
                    setState(() => _selectedDepartment = 'All');
                    _fetchStageData(page: 1);
                  }),
                if (_selectedStage != 'All')
                  _buildActiveFilterChip('Stage: $_selectedStage', () {
                    setState(() => _selectedStage = 'All');
                    _fetchStageData(page: 1);
                  }),
                if (_selectedPosition != 'All')
                  _buildActiveFilterChip('Role: $_selectedPosition', () {
                    setState(() => _selectedPosition = 'All');
                    _fetchStageData(page: 1);
                  }),
                if (_selectedSource != 'All')
                  _buildActiveFilterChip('Source: $_selectedSource', () {
                    setState(() => _selectedSource = 'All');
                    _fetchStageData(page: 1);
                  }),
                if (_searchQuery.trim().isNotEmpty)
                  _buildActiveFilterChip('Search: "$_searchQuery"', () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _fetchStageData(page: 1);
                  }),
                InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedStage = 'All';
                      _selectedDepartment = 'All';
                      _selectedPosition = 'All';
                      _selectedSource = 'All';
                    });
                    _fetchStageData(page: 1);
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
          const SizedBox(height: 12),

            // Bulk Actions Bar (Shown when candidates selected)
            if (_selectedCandidateIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedCandidateIds.length} candidate(s) selected',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Move Selected Candidates',
                      offset: const Offset(0, 36),
                      constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (target) {
                        if (target == '__open_stepper__') return;
                        if (target == '__reject__') {
                          _executeBulkAction('reject');
                          return;
                        }
                        _executeBulkAction('move_stage', targetStage: target);
                      },
                      itemBuilder: (ctx) => RecruitmentPipelineStage.buildPipelineMenu(
                        context: ctx,
                        currentStage: widget.stage,
                        isBulk: true,
                        bulkCount: _selectedCandidateIds.length,
                        includeModalTrigger: false,
                        includeRejectAction: true,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.drive_file_move_outlined, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text('Move Stage', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _executeBulkAction('reject'),
                      icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                      label: const Text('Bulk Reject', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedCandidateIds.isNotEmpty) const SizedBox(height: 10),

            // Candidate Table / Workspace
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444))),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: () => _fetchStageData(), child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _candidates.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_search_rounded,
                                      size: 56,
                                      color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      widget.jobTitle != null
                                          ? 'No candidates have applied for "${widget.jobTitle}" yet.'
                                          : 'No candidates found in ${widget.stage} stage for current filters.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.jobTitle != null
                                          ? 'When applicants apply from the Public Careers portal or are added by recruiters, they will appear here.'
                                          : 'Try adjusting your search criteria or changing stage filters.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                                  ),
                                  horizontalMargin: 12,
                                  columnSpacing: 20,
                                  dataRowMaxHeight: 56,
                                  columns: [
                                    DataColumn(
                                      label: Checkbox(
                                        value: _selectAll,
                                        onChanged: (val) {
                                          setState(() {
                                            _selectAll = val ?? false;
                                            if (_selectAll) {
                                              _selectedCandidateIds.addAll(
                                                _candidates.map((c) => c['candidate_id'].toString()),
                                              );
                                            } else {
                                              _selectedCandidateIds.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const DataColumn(label: Text('Candidate', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Position', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Experience', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Applied Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Source', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Stage & Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Interview', style: TextStyle(fontWeight: FontWeight.bold))),
                                    const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _candidates.map((cand) {
                                    final candId = cand['candidate_id'].toString();
                                    final appId = cand['application_id'].toString();
                                    final isChecked = _selectedCandidateIds.contains(candId);
                                    final interview = cand['latest_interview'];
                                    final candidateStage = cand['current_stage']?.toString() ?? widget.stage;

                                    return DataRow(
                                      selected: isChecked,
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: isChecked,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedCandidateIds.add(candId);
                                                } else {
                                                  _selectedCandidateIds.remove(candId);
                                                }
                                                _selectAll = _selectedCandidateIds.length == _candidates.length;
                                              });
                                            },
                                          ),
                                        ),
                                        // Candidate Avatar & Name
                                        DataCell(
                                          InkWell(
                                            onTap: () => _openCandidateDrawer(candId),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                                  child: Text(
                                                    (cand['full_name'] ?? 'C')[0].toUpperCase(),
                                                    style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      cand['full_name'] ?? '',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                    Text(
                                                      cand['email'] ?? cand['candidate_code'] ?? '',
                                                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Position & Dept
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(cand['job_title'] ?? '-', style: const TextStyle(fontSize: 13)),
                                              Text(cand['department'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            ],
                                          ),
                                        ),
                                        // Experience
                                        DataCell(Text('${cand['experience_years'] ?? 0} yrs', style: const TextStyle(fontSize: 12))),
                                        // Applied Date
                                        DataCell(Text(
                                          cand['applied_date'] != null
                                              ? cand['applied_date'].toString().split('T')[0]
                                              : '-',
                                          style: const TextStyle(fontSize: 12),
                                        )),
                                        // Source
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              cand['source'] ?? 'Direct',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ),
                                        // Stage & Status (Interactive Progression Chip)
                                        DataCell(
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              PopupMenuButton<String>(
                                                tooltip: 'Recruitment Progression for ${cand['full_name']}',
                                                offset: const Offset(0, 32),
                                                constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                onSelected: (target) {
                                                  if (target == '__open_stepper__') {
                                                    _openStageProgressionDialogFor(cand);
                                                  } else if (target == '__reject__') {
                                                    _rejectApplication(appId);
                                                  } else {
                                                    _moveStage(appId, target);
                                                  }
                                                },
                                                itemBuilder: (ctx) => RecruitmentPipelineStage.buildPipelineMenu(
                                                  context: ctx,
                                                  currentStage: candidateStage,
                                                  includeModalTrigger: true,
                                                  includeRejectAction: true,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: _getStageColor(candidateStage).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(color: _getStageColor(candidateStage).withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        candidateStage,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: _getStageColor(candidateStage),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Icon(Icons.arrow_drop_down, size: 14, color: _getStageColor(candidateStage)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (cand['stage_status'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2, left: 2),
                                                  child: Text(
                                                    cand['stage_status'].toString(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Interview info
                                        DataCell(
                                          interview != null
                                              ? Text(
                                                  '${interview['round'] ?? 'Round'}: ${interview['status'] ?? ''}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5)),
                                                )
                                              : const Text('None', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                        ),
                                        // Actions Menu
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                                tooltip: 'View Profile',
                                                color: const Color(0xFF4F46E5),
                                                onPressed: () => _openCandidateDrawer(candId),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, size: 18),
                                                offset: const Offset(0, 36),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                onSelected: (val) {
                                                  if (val == 'next') {
                                                    final next = RecruitmentPipelineStage.getNextStage(candidateStage);
                                                    if (next != null) {
                                                      _moveStage(appId, next.key);
                                                    }
                                                  } else if (val == 'prev') {
                                                    final prev = RecruitmentPipelineStage.getPreviousStage(candidateStage);
                                                    if (prev != null) {
                                                      _moveStage(appId, prev.key);
                                                    }
                                                  } else if (val == 'stepper') {
                                                    _openStageProgressionDialogFor(cand);
                                                  } else if (val == 'interview') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => ScheduleInterviewDialog(
                                                        applicationId: appId,
                                                        candidateName: cand['full_name'] ?? '',
                                                        jobTitle: cand['job_title'] ?? '',
                                                        onScheduled: () {
                                                          _fetchStageData(page: _pagination['page'] ?? 1);
                                                          widget.onDataChanged();
                                                        },
                                                      ),
                                                    );
                                                  } else if (val == 'drawer') {
                                                    _openCandidateDrawer(candId);
                                                  } else if (val == 'reject') {
                                                    _rejectApplication(appId);
                                                  }
                                                },
                                                itemBuilder: (ctx) {
                                                  final nextStage = RecruitmentPipelineStage.getNextStage(candidateStage);
                                                  final prevStage = RecruitmentPipelineStage.getPreviousStage(candidateStage);
                                                  return [
                                                    if (nextStage != null)
                                                      PopupMenuItem(
                                                        value: 'next',
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF10B981)),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                'Advance to: ${nextStage.label}',
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    if (prevStage != null)
                                                      PopupMenuItem(
                                                        value: 'prev',
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.arrow_back_rounded, size: 15, color: Color(0xFFF59E0B)),
                                                            const SizedBox(width: 8),
                                                            Expanded(
                                                              child: Text(
                                                                'Rollback to: ${prevStage.label}',
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    const PopupMenuItem(
                                                      value: 'stepper',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.tune_rounded, size: 15, color: Color(0xFF4F46E5)),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Pipeline Stepper...',
                                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(
                                                      value: 'interview',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.event_available_outlined, size: 15, color: Color(0xFF64748B)),
                                                          SizedBox(width: 8),
                                                          Text('Schedule Interview', style: TextStyle(fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'drawer',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.badge_outlined, size: 15, color: Color(0xFF64748B)),
                                                          SizedBox(width: 8),
                                                          Text('Candidate 360 View', style: TextStyle(fontSize: 12)),
                                                        ],
                                                      ),
                                                    ),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(
                                                      value: 'reject',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.cancel_outlined, size: 15, color: Color(0xFFEF4444)),
                                                          SizedBox(width: 8),
                                                          Text('Reject Application', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                                        ],
                                                      ),
                                                    ),
                                                  ];
                                                },
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

            // Pagination Controls
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final startRecord = _candidates.isNotEmpty ? ((currentPage - 1) * _pageSize) + 1 : 0;
                final endRecord = _candidates.isNotEmpty ? ((currentPage - 1) * _pageSize) + _candidates.length : 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _candidates.isEmpty
                            ? 'Showing 0 to 0 of $totalRecords candidates'
                            : 'Showing $startRecord to $endRecord of $totalRecords candidates',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Records Per Page Dropdown
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _pageSize,
                              isDense: true,
                              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600),
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('5 per page')),
                                DropdownMenuItem(value: 10, child: Text('10 per page')),
                                DropdownMenuItem(value: 20, child: Text('20 per page')),
                                DropdownMenuItem(value: 50, child: Text('50 per page')),
                                DropdownMenuItem(value: 100, child: Text('100 per page')),
                              ],
                              onChanged: (newSize) {
                                if (newSize != null && newSize != _pageSize) {
                                  setState(() {
                                    _pageSize = newSize;
                                  });
                                  _fetchStageData(page: 1);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Navigation Controls
                        IconButton(
                          icon: const Icon(Icons.first_page_rounded, size: 18),
                          tooltip: 'First Page',
                          onPressed: currentPage > 1 ? () => _fetchStageData(page: 1) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 20),
                          tooltip: 'Previous Page',
                          onPressed: currentPage > 1 ? () => _fetchStageData(page: currentPage - 1) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$currentPage of $totalPages',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 20),
                          tooltip: 'Next Page',
                          onPressed: currentPage < totalPages ? () => _fetchStageData(page: currentPage + 1) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.last_page_rounded, size: 18),
                          tooltip: 'Last Page',
                          onPressed: currentPage < totalPages ? () => _fetchStageData(page: totalPages) : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
