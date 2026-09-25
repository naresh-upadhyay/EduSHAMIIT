import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'stage_details_dialog.dart';
import 'create_job_dialog.dart';

class JobOpeningsListDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialJobs;
  final VoidCallback onDataChanged;

  const JobOpeningsListDialog({
    super.key,
    required this.initialJobs,
    required this.onDataChanged,
  });

  @override
  State<JobOpeningsListDialog> createState() => _JobOpeningsListDialogState();
}

class _JobOpeningsListDialogState extends State<JobOpeningsListDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = false;
  String _selectedStatus = 'Active'; // 'Active', 'Draft', 'All'
  final String _selectedDepartment = 'All';

  @override
  void initState() {
    super.initState();
    _jobs = List<Map<String, dynamic>>.from(widget.initialJobs);
    if (_jobs.isEmpty) {
      _fetchJobs();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/recruitment/jobs?limit=500', useCache: false);
      final List items = res['data'] ?? res['items'] ?? [];
      if (mounted) {
        setState(() {
          _jobs = items.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    return _jobs.where((j) {
      final status = (j['publishing_status'] ?? '').toString();
      if (_selectedStatus == 'Active' && status != 'Active') return false;
      if (_selectedStatus == 'Draft' && status != 'Draft') return false;

      final dept = (j['department'] ?? '').toString();
      if (_selectedDepartment != 'All' && dept != _selectedDepartment) return false;

      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final title = (j['job_title'] ?? '').toString().toLowerCase();
        final code = (j['job_code'] ?? '').toString().toLowerCase();
        final deptLower = dept.toLowerCase();
        if (!title.contains(query) && !code.contains(query) && !deptLower.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openStageDetailsForJob(Map<String, dynamic> j) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StageDetailsDialog(
        stage: 'All',
        jobId: j['id']?.toString(),
        jobTitle: j['job_title']?.toString(),
        jobCode: j['job_code']?.toString(),
        candidateCount: (j['total_applicants'] ?? j['applicant_count'] ?? 0) as int,
        onDataChanged: () {
          _fetchJobs();
          widget.onDataChanged();
        },
      ),
    );
  }

  Future<void> _toggleJobPublic(Map<String, dynamic> j) async {
    final originalIsPublic = j['is_public'] == true;
    final newIsPublic = !originalIsPublic;

    // Optimistically update local state immediately so position count and UI remain 100% correct & intact
    setState(() {
      j['is_public'] = newIsPublic;
      final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
      if (idx != -1) {
        _jobs[idx]['is_public'] = newIsPublic;
      }
    });

    try {
      final res = await _api.post('/recruitment/jobs/${j['id']}/toggle-public', {});
      if (mounted) {
        final isNowPublic = res['data']?['is_public'] == true || res['is_public'] == true;
        setState(() {
          j['is_public'] = isNowPublic;
          final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
          if (idx != -1) {
            _jobs[idx]['is_public'] = isNowPublic;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowPublic ? 'Job published to Public Careers!' : 'Job unpublished from Public Careers.'),
            backgroundColor: isNowPublic ? const Color(0xFF16A34A) : const Color(0xFF475569),
            duration: const Duration(seconds: 2),
          ),
        );
        widget.onDataChanged();
      }
    } catch (e) {
      if (mounted) {
        // Revert on failure
        setState(() {
          j['is_public'] = originalIsPublic;
          final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
          if (idx != -1) {
            _jobs[idx]['is_public'] = originalIsPublic;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update visibility: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredJobs;
    final activeCount = _jobs.where((j) => j['publishing_status'] == 'Active').length;
    final draftCount = _jobs.where((j) => j['publishing_status'] == 'Draft').length;

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
                        child: const Icon(Icons.work_outline_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Job Openings Directory',
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
                                    '${filtered.length} Positions',
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
                              'Complete repository of institutional job postings, vacancies fulfillment, visibility controls and candidate links.',
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh Openings',
                      onPressed: _fetchJobs,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => CreateJobDialog(
                            onJobCreated: () {
                              _fetchJobs();
                              widget.onDataChanged();
                            },
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Job Opening', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Controls Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1426) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Status Pills
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusPill('Active ($activeCount)', 'Active', isDark),
                      const SizedBox(width: 8),
                      _buildStatusPill('Draft ($draftCount)', 'Draft', isDark),
                      const SizedBox(width: 8),
                      _buildStatusPill('All (${_jobs.length})', 'All', isDark),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(height: 24, width: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  const SizedBox(width: 16),

                  // Search input
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() {}),
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search jobs by title, department, job code...',
                          hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF13182C) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Content Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.work_off_outlined, size: 54, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              Text(
                                'No job openings found matching the criteria.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try changing your status tab or clearing search queries.',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    isDark ? const Color(0xFF0F1426) : const Color(0xFFF1F5F9),
                                  ),
                                  columnSpacing: 22,
                                  dataRowMaxHeight: 58,
                                  columns: const [
                                    DataColumn(label: Text('Job Title & Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Vacancies', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Applicants', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Status & Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Visibility', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Deadline', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: filtered.map((job) {
                                    final title = (job['job_title'] ?? 'Untitled').toString();
                                    final code = (job['job_code'] ?? '---').toString();
                                    final dept = (job['department'] ?? '---').toString();
                                    final vacancies = (job['vacancies'] ?? 1).toString();
                                    final filledVacancies = (job['filled_vacancies'] ?? 0).toString();
                                    final applicants = job['total_applicants'] ?? job['applicant_count'] ?? 0;
                                    final status = (job['publishing_status'] ?? 'Draft').toString();
                                    final isPublic = job['is_public'] == true;
                                    final deadline = job['application_deadline']?.toString() ?? 'No deadline';
                                    final slug = job['slug']?.toString() ?? '';

                                    return DataRow(
                                      cells: [
                                        // Title & Code
                                        DataCell(
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                              Text(
                                                code,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Department
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              dept,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ),

                                        // Vacancies
                                        DataCell(
                                          Text('$filledVacancies / $vacancies', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                        ),

                                        // Applicants (Clickable)
                                        DataCell(
                                          InkWell(
                                            onTap: () => _openStageDetailsForJob(job),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: applicants > 0
                                                    ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.people_alt_outlined,
                                                    size: 14,
                                                    color: applicants > 0 ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$applicants',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: applicants > 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Status
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: status == 'Active'
                                                  ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                                  : (status == 'Draft'
                                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                                                      : const Color(0xFF64748B).withValues(alpha: 0.1)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'Active'
                                                    ? const Color(0xFF16A34A)
                                                    : (status == 'Draft' ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Visibility
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPublic ? Icons.public : Icons.lock_outline,
                                                size: 14,
                                                color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isPublic ? 'Public Portal' : 'Internal Only',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Deadline
                                        DataCell(
                                          Text(deadline, style: const TextStyle(fontSize: 11)),
                                        ),

                                        // Actions
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Tooltip(
                                                message: 'View Candidates',
                                                child: IconButton(
                                                  icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                                                  onPressed: () => _openStageDetailsForJob(job),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Tooltip(
                                                message: isPublic ? 'Make Private' : 'Publish to Careers',
                                                child: IconButton(
                                                  icon: Icon(
                                                    isPublic ? Icons.public : Icons.public_off,
                                                    size: 16,
                                                    color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                                  ),
                                                  onPressed: () => _toggleJobPublic(job),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              if (isPublic && slug.isNotEmpty)
                                                Tooltip(
                                                  message: 'Copy Public Link',
                                                  child: IconButton(
                                                    icon: const Icon(Icons.link, size: 16, color: Color(0xFF0D9488)),
                                                    onPressed: () async {
                                                      final url = '${Uri.base.origin}/careers/jobs/$slug';
                                                      await Clipboard.setData(ClipboardData(text: url));
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Public link copied: $url'), backgroundColor: const Color(0xFF16A34A)),
                                                        );
                                                      }
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
                                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String label, String status, bool isDark) {
    final isSelected = _selectedStatus == status;
    return InkWell(
      onTap: () => setState(() => _selectedStatus = status),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }
}
