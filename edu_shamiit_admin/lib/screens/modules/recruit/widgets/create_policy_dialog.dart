import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'searchable_reviewer_picker.dart';

class CreatePolicyDialog extends StatefulWidget {
  final VoidCallback onPolicyCreated;
  final Map<String, dynamic>? initialPolicy;

  const CreatePolicyDialog({
    super.key,
    required this.onPolicyCreated,
    this.initialPolicy,
  });

  @override
  State<CreatePolicyDialog> createState() => _CreatePolicyDialogState();
}

class _CreatePolicyDialogState extends State<CreatePolicyDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isSubmitting = false;
  List<dynamic> _categories = [];
  List<String> _departments = [];
  List<Map<String, dynamic>> _roles = [];

  // Form Controllers
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _ownerController = TextEditingController(text: 'HR Department');
  final _versionController = TextEditingController(text: '1.0');
  final _contentController = TextEditingController();
  final _targetValueController = TextEditingController();

  String? _selectedCategory;
  String? _selectedDepartment;
  String _applicabilityType = 'Entire Institute';
  String _reviewFrequency = 'Annual';

  DateTime _effectiveDate = DateTime.now();
  DateTime _reviewDate = DateTime.now().add(const Duration(days: 365));
  DateTime? _expiryDate;
  DateTime _ackDeadline = DateTime.now().add(const Duration(days: 30));

  bool _ackRequired = true;
  bool _ackMandatory = true;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  List<String> _applicabilityOptions = ['Entire Institute', 'Department', 'Role', 'Selected Users'];
  List<String> _reviewFrequencies = HRLookupHelper.instance.getCachedLabels('POLICY_REVIEW_FREQUENCY');

  // Employee search & selection for "Selected Users"
  final _employeeSearchController = TextEditingController();
  Timer? _employeeSearchTimer;
  bool _isSearchingEmployees = false;
  List<Map<String, dynamic>> _employeeSearchResults = [];
  final List<Map<String, dynamic>> _selectedEmployees = [];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _tabController = TabController(length: 4, vsync: this);
    _departments = HRLookupHelper.instance.getCachedLabels('DEPARTMENT');

    _loadCategories();
    _loadLookups(true);
    _loadRoles();

    if (widget.initialPolicy != null) {
      final p = widget.initialPolicy!;
      _titleController.text = p['title'] ?? '';
      _codeController.text = p['policy_code'] ?? '';
      _descController.text = p['description'] ?? '';
      _ownerController.text = p['policy_owner_name'] ?? p['policy_owner'] ?? 'HR Department';
      _selectedDepartment = p['department'];
      _versionController.text = p['current_version'] ?? '1.0';
      _contentController.text = p['content_html'] ?? '';
      _selectedCategory = p['category_name'];

      final rawAudience = p['audience_type'] ?? p['applicability_type'] ?? 'Entire Institute';
      _applicabilityType = rawAudience.toString().toLowerCase() == 'designation' ? 'Role' : rawAudience;
      _targetValueController.text = p['audience_target'] ?? p['applicability_target'] ?? '';

      _reviewFrequency = p['review_frequency'] ?? 'Annual';
      _ackRequired = p['acknowledgement_required'] != false;
      _ackMandatory = p['acknowledgement_mandatory'] != false;

      if (p['effective_date'] != null) {
        _effectiveDate = DateTime.tryParse(p['effective_date'].toString()) ?? _effectiveDate;
      }
      if (p['review_date'] != null) {
        _reviewDate = DateTime.tryParse(p['review_date'].toString()) ?? _reviewDate;
      }
      if (p['expiry_date'] != null) {
        _expiryDate = DateTime.tryParse(p['expiry_date'].toString());
      }
      if (p['acknowledgement_deadline'] != null) {
        _ackDeadline = DateTime.tryParse(p['acknowledgement_deadline'].toString()) ?? _ackDeadline;
      }

      if (p['target_users'] is List) {
        _selectedEmployees.addAll(List<Map<String, dynamic>>.from(p['target_users']));
      }
    } else {
      _codeController.text = 'POL-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 90000) + 10000}';
      _contentController.text = '''<h3>1. Purpose & Scope</h3>
<p>This policy outlines institutional standards and compliance requirements for all personnel at EduSHAMIIT.</p>

<h3>2. Responsibilities</h3>
<ul>
  <li>Employees are required to read, understand, and comply with all directives.</li>
  <li>Department heads are responsible for ensuring enforcement and periodic training.</li>
</ul>

<h3>3. Guidelines & Standard Procedures</h3>
<p>All institutional activities must adhere to the standard operating procedures defined herein.</p>

<h3>4. Non-Compliance</h3>
<p>Failure to adhere to institutional policies may result in disciplinary action in accordance with service rules.</p>''';
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _employeeSearchTimer?.cancel();
    _employeeSearchController.dispose();
    _tabController.dispose();
    _titleController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _ownerController.dispose();
    _versionController.dispose();
    _contentController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get('/hr/categories', useCache: true);
      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
          if (_selectedCategory == null && _categories.isNotEmpty) {
            _selectedCategory = _categories.first['name'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRoles() async {
    try {
      final res = await _api.get('/admin/schools/roles?status=Active', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data'])
            .where((r) => (r['status'] ?? 'Active').toString().toLowerCase() == 'active')
            .toList();
        if (mounted) {
          setState(() {
            _roles = list;
            if (_applicabilityType == 'Role' && _targetValueController.text.trim().isEmpty && _roles.isNotEmpty) {
              _targetValueController.text = (_roles.first['display_name'] ?? _roles.first['name'] ?? '').toString();
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final appls = await HRLookupHelper.instance.getLookupLabels('POLICY_APPLICABILITY', forceRefresh: forceRefresh);
    final freqs = await HRLookupHelper.instance.getLookupLabels('POLICY_REVIEW_FREQUENCY', forceRefresh: forceRefresh);

    if (mounted) {
      setState(() {
        _departments = depts;
        if (_selectedDepartment == null && _departments.isNotEmpty) {
          _selectedDepartment = _departments.first;
        } else if (_selectedDepartment != null && !_departments.contains(_selectedDepartment)) {
          _departments.insert(0, _selectedDepartment!);
        }

        if (_applicabilityType == 'Department' && _targetValueController.text.trim().isEmpty && _departments.isNotEmpty) {
          _targetValueController.text = _departments.first;
        }

        final normalizedAppls = appls.map((a) => a.toLowerCase() == 'designation' ? 'Role' : a).toSet().toList();
        if (normalizedAppls.isNotEmpty) {
          _applicabilityOptions = normalizedAppls;
        }
        if (!_applicabilityOptions.contains(_applicabilityType) && _applicabilityOptions.isNotEmpty) {
          _applicabilityType = _applicabilityOptions.first;
        }

        _reviewFrequencies = freqs;
        if (!_reviewFrequencies.contains(_reviewFrequency) && _reviewFrequencies.isNotEmpty) {
          _reviewFrequency = _reviewFrequencies.first;
        }
      });
    }
  }

  Future<void> _searchEmployees(String query) async {
    setState(() => _isSearchingEmployees = true);
    try {
      final res = await _api.get('/hr/employees', query: {'search': query.trim()}, useCache: false);
      if (res['success'] == true && mounted) {
        setState(() {
          _employeeSearchResults = List<Map<String, dynamic>>.from(res['data'] ?? []);
          _isSearchingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingEmployees = false);
    }
  }

  void _onEmployeeSearchChanged(String query) {
    _employeeSearchTimer?.cancel();
    _employeeSearchTimer = Timer(const Duration(milliseconds: 300), () {
      _searchEmployees(query);
    });
  }

  void _toggleEmployee(Map<String, dynamic> emp) {
    setState(() {
      final idx = _selectedEmployees.indexWhere((e) => e['id'] == emp['id']);
      if (idx >= 0) {
        _selectedEmployees.removeAt(idx);
      } else {
        _selectedEmployees.add(emp);
      }
      _employeeSearchController.clear();
      _employeeSearchResults.clear();
    });
  }

  Future<void> _pickDate(BuildContext context, String field) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (field == 'effective') initial = _effectiveDate;
    if (field == 'review') initial = _reviewDate;
    if (field == 'expiry') initial = _expiryDate ?? now.add(const Duration(days: 730));
    if (field == 'deadline') initial = _ackDeadline;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (field == 'effective') {
          _effectiveDate = picked;
          if (_reviewDate.isBefore(_effectiveDate)) {
            _reviewDate = _effectiveDate.add(const Duration(days: 365));
          }
        } else if (field == 'review') {
          _reviewDate = picked;
        } else if (field == 'expiry') {
          _expiryDate = picked;
        } else if (field == 'deadline') {
          _ackDeadline = picked;
        }
      });
    }
  }

  Future<void> _promptReviewerSelectionAndSubmit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Policy Title first'), backgroundColor: Colors.orange),
      );
      _tabController.animateTo(0);
      return;
    }

    final commentsController = TextEditingController();
    Map<String, dynamic>? selectedReviewer;
    List<Map<String, dynamic>> candidateReviewers = [];

    try {
      final res = await _api.get('/hr/employees', query: {'limit': 50}, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        candidateReviewers = List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Submit Policy for Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: math.min(520.0, MediaQuery.of(context).size.width * 0.9),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the designated reviewer/approver who will evaluate this policy before it is approved and published:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Reviewer / Approver *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SearchableReviewerPicker(
                    candidateReviewers: candidateReviewers,
                    selectedReviewer: selectedReviewer,
                    onReviewerSelected: (emp) {
                      setModalState(() {
                        selectedReviewer = emp;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Review Instructions / Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: commentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Please review section 2 regarding compliance standards...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (selectedReviewer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a reviewer to evaluate this policy'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
              label: const Text('Submit for Review', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedReviewer != null) {
      await _submitPolicy(
        'PENDING_REVIEW',
        reviewer: selectedReviewer,
        reviewComments: commentsController.text.trim(),
      );
    }
  }

  Future<void> _submitPolicy(
    String targetStatus, {
    Map<String, dynamic>? reviewer,
    String? reviewComments,
  }) async {
    // For DRAFT, do not strictly block on secondary tab validations
    if (targetStatus == 'DRAFT') {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least a Policy Title to save draft.'), backgroundColor: Colors.orange),
        );
        _tabController.animateTo(0);
        return;
      }
    } else {
      if (!_formKey.currentState!.validate()) {
        _tabController.animateTo(0);
        return;
      }

      if (_applicabilityType == 'Selected Users' && _selectedEmployees.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please search and select at least one employee for Selected Users audience.'), backgroundColor: Colors.orange),
        );
        _tabController.animateTo(0);
        return;
      }

      if (_reviewDate.isBefore(_effectiveDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review date cannot be before effective date'), backgroundColor: Colors.red),
        );
        _tabController.animateTo(2);
        return;
      }

      if (_expiryDate != null && _expiryDate!.isBefore(_effectiveDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expiry date cannot be before effective date'), backgroundColor: Colors.red),
        );
        _tabController.animateTo(2);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    String targetVal = _targetValueController.text.trim();
    if (targetVal.isEmpty) {
      if (_applicabilityType == 'Role' && _roles.isNotEmpty) {
        targetVal = (_roles.first['display_name'] ?? _roles.first['name'] ?? '').toString();
      } else if (_applicabilityType == 'Department' && _departments.isNotEmpty) {
        targetVal = _departments.first;
      }
    }

    final payload = {
      'policy_code': _codeController.text.trim().isNotEmpty
          ? _codeController.text.trim()
          : 'POL-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 90000) + 10000}',
      'title': _titleController.text.trim(),
      'category_name': _selectedCategory ?? 'General',
      'description': _descController.text.trim(),
      'policy_owner': _ownerController.text.trim(),
      'policy_owner_name': _ownerController.text.trim(),
      'department': _selectedDepartment ?? 'General',
      'version': _versionController.text.trim().isNotEmpty ? _versionController.text.trim() : '1.0',
      'applicability_type': _applicabilityType,
      'audience_type': _applicabilityType,
      'applicability_target': targetVal,
      'audience_target': targetVal,
      'target_user_ids': _applicabilityType == 'Selected Users'
          ? _selectedEmployees.map((e) => e['id'] as String).toList()
          : null,
      'effective_date': _dateFormat.format(_effectiveDate),
      'review_date': _dateFormat.format(_reviewDate),
      'expiry_date': _expiryDate != null ? _dateFormat.format(_expiryDate!) : null,
      'review_frequency': _reviewFrequency,
      'acknowledgement_required': _ackRequired,
      'acknowledgement_mandatory': _ackMandatory,
      'acknowledgement_deadline': _dateFormat.format(_ackDeadline),
      'content_html': _contentController.text.trim(),
      'status': targetStatus,
    };

    if (reviewer != null) {
      payload['reviewer_id'] = reviewer['id'];
      payload['reviewer_name'] = reviewer['full_name'] ?? reviewer['email'];
      payload['reviewer_role'] = reviewer['role'] ?? 'Reviewer';
      if (reviewComments != null && reviewComments.isNotEmpty) {
        payload['review_comments'] = reviewComments;
      }
    }

    try {
      final isEdit = widget.initialPolicy != null;
      final res = isEdit
          ? await _api.patch('/hr/policies/${widget.initialPolicy!['id']}', payload)
          : await _api.post('/hr/policies', payload);
      if (res['success'] == true) {
        widget.onPolicyCreated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit
                  ? 'Policy updated successfully!'
                  : targetStatus == 'DRAFT'
                      ? 'Policy saved as draft'
                      : targetStatus == 'ACTIVE'
                          ? 'Policy published successfully!'
                          : 'Policy submitted for review'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to save policy'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(880.0, size.width * 0.95);
    final dialogHeight = math.min(740.0, size.height * 0.92);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogHeight),
        padding: EdgeInsets.all(size.width < 600 ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                          child: const Icon(Icons.policy_rounded, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.initialPolicy != null ? 'Edit Institutional Policy' : 'Create Institutional Policy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Author, configure dynamic applicability, set review lifecycle and publishing workflow.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tab Bar Navigation
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4F46E5),
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: '1. Basic Info'),
                  Tab(icon: Icon(Icons.article_outlined, size: 16), text: '2. Policy Content'),
                  Tab(icon: Icon(Icons.event_repeat_rounded, size: 16), text: '3. Lifecycle & Dates'),
                  Tab(icon: Icon(Icons.verified_user_outlined, size: 16), text: '4. Acknowledgement'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBasicInfoTab(isDark),
                    _buildContentTab(isDark),
                    _buildLifecycleTab(isDark),
                    _buildAcknowledgementTab(isDark),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Bottom Action Buttons
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitPolicy('DRAFT'),
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save Draft'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _promptReviewerSelectionAndSubmit,
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Submit for Review'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitPolicy('ACTIVE'),
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.publish_rounded, size: 16, color: Colors.white),
                        label: Text(_isSubmitting ? 'Publishing...' : 'Publish Policy', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _titleController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Policy Title *',
                    hintText: 'e.g. Institutional Code of Conduct & Ethics',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _codeController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Policy Code *',
                    hintText: 'e.g. POL-HR-001',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;
              final catWidget = DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _categories.map<DropdownMenuItem<String>>((c) {
                  final catName = c['name'] as String;
                  return DropdownMenuItem<String>(
                    value: catName,
                    child: Text(catName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              );

              final deptWidget = DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _departments.contains(_selectedDepartment)
                    ? _selectedDepartment
                    : (_departments.isNotEmpty ? _departments.first : null),
                decoration: InputDecoration(
                  labelText: 'Department *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem<String>(
                    value: dept,
                    child: Text(dept, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDepartment = val),
              );

              final verWidget = TextFormField(
                controller: _versionController,
                decoration: InputDecoration(
                  labelText: 'Initial Version',
                  hintText: 'e.g. 1.0',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    catWidget,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: deptWidget),
                        const SizedBox(width: 12),
                        Expanded(child: verWidget),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: catWidget),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: deptWidget),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: verWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Policy Description / Summary',
              hintText: 'Brief objective and overview of this institutional regulation...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Applicability & Audience', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 620;
              final audienceDropdown = DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _applicabilityOptions.contains(_applicabilityType)
                    ? _applicabilityType
                    : (_applicabilityOptions.isNotEmpty ? _applicabilityOptions.first : null),
                decoration: InputDecoration(
                  labelText: 'Applicable Audience',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _applicabilityOptions.map((opt) {
                  return DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _applicabilityType = val;
                      if (val == 'Role' && _roles.isNotEmpty) {
                        _targetValueController.text = (_roles.first['display_name'] ?? _roles.first['name'] ?? '').toString();
                      } else if (val == 'Department' && _departments.isNotEmpty) {
                        _targetValueController.text = _departments.first;
                      } else {
                        _targetValueController.clear();
                      }
                    });
                  }
                },
              );

              Widget? secondaryDropdown;
              if (_applicabilityType == 'Department') {
                secondaryDropdown = DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _departments.contains(_targetValueController.text)
                      ? _targetValueController.text
                      : (_departments.isNotEmpty ? _departments.first : null),
                  decoration: InputDecoration(
                    labelText: 'Target Department *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(value: dept, child: Text(dept, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _targetValueController.text = val);
                  },
                );
              } else if (_applicabilityType == 'Role') {
                secondaryDropdown = DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _roles.any((r) => (r['display_name'] ?? r['name']) == _targetValueController.text)
                      ? _targetValueController.text
                      : (_roles.isNotEmpty ? (_roles.first['display_name'] ?? _roles.first['name']) : null),
                  decoration: InputDecoration(
                    labelText: 'Target Role *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _roles.map((r) {
                    final roleName = (r['display_name'] ?? r['name'] ?? 'Staff').toString();
                    return DropdownMenuItem(value: roleName, child: Text(roleName, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _targetValueController.text = val);
                  },
                );
              }

              if (secondaryDropdown == null) {
                return audienceDropdown;
              }

              if (isNarrow) {
                return Column(
                  children: [
                    audienceDropdown,
                    const SizedBox(height: 12),
                    secondaryDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: audienceDropdown),
                  const SizedBox(width: 14),
                  Expanded(child: secondaryDropdown),
                ],
              );
            },
          ),

          // Multi-User Search & Select when "Selected Users" is active
          if (_applicabilityType == 'Selected Users') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _employeeSearchController,
              decoration: InputDecoration(
                labelText: 'Search & Select Staff Users *',
                hintText: 'Type employee name, email, department, or role...',
                prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFF4F46E5)),
                suffixIcon: _isSearchingEmployees
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : (_employeeSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _employeeSearchController.clear();
                              setState(() => _employeeSearchResults.clear());
                            },
                          )
                        : null),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: _onEmployeeSearchChanged,
            ),
            if (_employeeSearchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _employeeSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final emp = _employeeSearchResults[idx];
                    final isSelected = _selectedEmployees.any((e) => e['id'] == emp['id']);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: Text(
                          (emp['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      title: Text(emp['full_name'] ?? emp['email'] ?? 'Staff', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('${emp['role'] ?? 'Staff'} · ${emp['department'] ?? 'General'}', style: const TextStyle(fontSize: 11)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                          : const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 18),
                      onTap: () => _toggleEmployee(emp),
                    );
                  },
                ),
              ),
            ],
            if (_selectedEmployees.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected Users (${_selectedEmployees.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedEmployees.clear()),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 20)),
                          child: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.red)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedEmployees.map((emp) {
                        return Chip(
                          backgroundColor: isDark ? const Color(0xFF334155) : Colors.white,
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFF4F46E5),
                            child: Text(
                              (emp['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 9, color: Colors.white),
                            ),
                          ),
                          label: Text(
                            '${emp['full_name']} · ${emp['role'] ?? emp['department'] ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          onDeleted: () => _toggleEmployee(emp),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildContentTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Policy Document Body (HTML / Markdown Supported)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _contentController.text += '\n<h3>New Section</h3>\n<p>Enter text here...</p>\n';
                  },
                  icon: const Icon(Icons.title_rounded, size: 14),
                  label: const Text('+ Heading', style: TextStyle(fontSize: 11)),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _contentController.text += '\n<ul>\n  <li>Compliance point 1</li>\n  <li>Compliance point 2</li>\n</ul>\n';
                  },
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 14),
                  label: const Text('+ Bullets', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextFormField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Compose or paste policy content here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLifecycleTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lifecycle Dates & Review Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, 'effective'),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Effective Date *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(_dateFormat.format(_effectiveDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, 'review'),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Next Review Date *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(_dateFormat.format(_reviewDate)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, 'expiry'),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Expiry Date (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                    child: Text(_expiryDate != null ? _dateFormat.format(_expiryDate!) : 'No Expiry'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _reviewFrequencies.contains(_reviewFrequency)
                      ? _reviewFrequency
                      : (_reviewFrequencies.isNotEmpty ? _reviewFrequencies.first : null),
                  decoration: InputDecoration(
                    labelText: 'Periodic Review Frequency',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _reviewFrequencies.map((f) {
                    return DropdownMenuItem(value: f, child: Text(f));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _reviewFrequency = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _ownerController,
                  decoration: InputDecoration(
                    labelText: 'Policy Owner / Custodian',
                    hintText: 'e.g. HR Director, Principal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgementTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Digital Sign-off & Acknowledgement Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Require Employee Acknowledgement'),
            subtitle: const Text('Dispatches reading and sign-off requirements to all applicable staff members upon publishing.'),
            value: _ackRequired,
            activeThumbColor: const Color(0xFF4F46E5),
            onChanged: (v) => setState(() => _ackRequired = v),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Mandatory Compliance'),
            subtitle: const Text('Marks this policy as strictly mandatory with tracking against staff compliance records.'),
            value: _ackMandatory,
            activeThumbColor: const Color(0xFF4F46E5),
            onChanged: _ackRequired ? (v) => setState(() => _ackMandatory = v) : null,
          ),
          const Divider(),
          const SizedBox(height: 12),
          if (_ackRequired)
            InkWell(
              onTap: () => _pickDate(context, 'deadline'),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Acknowledgement Deadline',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: const Icon(Icons.timer_outlined, size: 18),
                ),
                child: Text(_dateFormat.format(_ackDeadline)),
              ),
            ),
        ],
      ),
    );
  }
}
