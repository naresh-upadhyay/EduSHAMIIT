import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class RequestAcknowledgementDialog extends StatefulWidget {
  final VoidCallback onRequested;
  final String? preselectedPolicyId;
  final String? preselectedPolicyTitle;
  final String? preselectedVersion;

  const RequestAcknowledgementDialog({
    super.key,
    required this.onRequested,
    this.preselectedPolicyId,
    this.preselectedPolicyTitle,
    this.preselectedVersion,
  });

  @override
  State<RequestAcknowledgementDialog> createState() => _RequestAcknowledgementDialogState();
}

class _RequestAcknowledgementDialogState extends State<RequestAcknowledgementDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _policies = [];
  String? _selectedPolicyId;
  String _selectedVersion = '1.0';

  String _audienceType = 'Specific Employee(s) (Search & Select)';
  final _targetValueController = TextEditingController();
  final _messageController = TextEditingController(text: 'Please review and sign off on this institutional policy.');
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  bool _isMandatory = true;
  bool _sendInAppNotification = true;
  bool _sendEmail = true;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Employee search and selection state
  final _employeeSearchController = TextEditingController();
  Timer? _employeeSearchTimer;
  bool _isSearchingEmployees = false;
  List<Map<String, dynamic>> _employeeSearchResults = [];
  final List<Map<String, dynamic>> _selectedEmployees = [];
  List<String> _departments = [];
  List<Map<String, dynamic>> _roles = [];

  List<String> _audienceOptions = [
    'Specific Employee(s) (Search & Select)',
    'Entire Institute',
    'Department',
    'Role',
  ];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _departments = HRLookupHelper.instance.getCachedLabels('DEPARTMENT');
    _selectedPolicyId = widget.preselectedPolicyId;
    _selectedVersion = widget.preselectedVersion ?? '1.0';
    if (widget.preselectedPolicyId != null) {
      _policies = [
        {
          'id': widget.preselectedPolicyId,
          'title': widget.preselectedPolicyTitle ?? 'Selected Policy',
          'current_version': widget.preselectedVersion ?? '1.0',
        }
      ];
      _isLoading = false;
    }
    _fetchPolicies();
    _loadLookups(true);
    _loadRoles();
    _searchEmployees('');
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
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
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final options = await HRLookupHelper.instance.getLookupLabels('POLICY_APPLICABILITY', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departments = depts;
        final normalized = options.map((o) => o.toLowerCase() == 'designation' ? 'Role' : o).toSet();
        final combined = <String>{
          'Specific Employee(s) (Search & Select)',
          'Entire Institute',
          'Department',
          'Role',
          ...normalized,
        }.toList();
        _audienceOptions = combined;
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _employeeSearchTimer?.cancel();
    _employeeSearchController.dispose();
    _targetValueController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPolicies() async {
    try {
      final res = await _api.get('/hr/policies', query: {'page_size': 50}, useCache: true);
      if (res['success'] == true) {
        setState(() {
          _policies = res['data'] ?? [];
          if (_selectedPolicyId == null && _policies.isNotEmpty) {
            _selectedPolicyId = _policies.first['id'];
            _selectedVersion = _policies.first['current_version'] ?? '1.0';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
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
    });
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedPolicyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a policy'), backgroundColor: Colors.red),
      );
      return;
    }

    final isSpecificEmployee = _audienceType == 'Specific Employee(s) (Search & Select)' ||
        _audienceType == 'Selected Users' ||
        _audienceType == 'Individual';

    if (isSpecificEmployee && _selectedEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select at least one employee to assign sign-off.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _api.post('/hr/acknowledgements/request', {
        'policy_id': _selectedPolicyId,
        'version_number': _selectedVersion,
        'audience_type': isSpecificEmployee ? 'Selected Users' : _audienceType,
        'target_user_ids': isSpecificEmployee ? _selectedEmployees.map((e) => e['id'] as String).toList() : null,
        'target_value': (!isSpecificEmployee && _targetValueController.text.trim().isNotEmpty)
            ? _targetValueController.text.trim()
            : null,
        'deadline': _dateFormat.format(_deadline),
        'is_mandatory': _isMandatory,
        'message': _messageController.text.trim(),
        'send_in_app_notification': _sendInAppNotification,
        'send_email': _sendEmail,
      });

      if (res['success'] == true) {
        widget.onRequested();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Acknowledgement requests dispatched successfully!'),
              backgroundColor: Colors.green,
            ),
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
    final isSpecificEmployee = _audienceType == 'Specific Employee(s) (Search & Select)' ||
        _audienceType == 'Selected Users' ||
        _audienceType == 'Individual';

    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(720.0, size.width * 0.95);
    final dialogHeight = math.min(800.0, size.height * 0.92);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogHeight),
        padding: EdgeInsets.all(size.width < 600 ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          child: const Icon(Icons.how_to_reg_rounded, color: Color(0xFF4F46E5), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request Policy Sign-off',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Search someone and assign them to review and provide institutional sign-off.',
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
              const Divider(height: 24),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 14, bottom: 16, left: 2, right: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Policy Selection
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedPolicyId,
                              decoration: InputDecoration(
                                labelText: 'Select Policy *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                suffixIcon: _isLoading && _policies.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : null,
                              ),
                              items: _policies.map<DropdownMenuItem<String>>((p) {
                                return DropdownMenuItem(
                                  value: p['id'] as String,
                                  child: Text(p['title'] ?? 'Policy'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final p = _policies.firstWhere((x) => x['id'] == val, orElse: () => null);
                                  setState(() {
                                    _selectedPolicyId = val;
                                    if (p != null) _selectedVersion = p['current_version'] ?? '1.0';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: _selectedVersion,
                              decoration: InputDecoration(
                                labelText: 'Version',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (v) => _selectedVersion = v.trim(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Target Audience Selector
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _audienceOptions.contains(_audienceType)
                                  ? _audienceType
                                  : (_audienceOptions.isNotEmpty ? _audienceOptions.first : null),
                              decoration: InputDecoration(
                                labelText: 'Audience / Sign-off Scope *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _audienceOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _audienceType = val);
                                  if ((val == 'Specific Employee(s) (Search & Select)' || val == 'Selected Users') &&
                                      _employeeSearchResults.isEmpty) {
                                    _searchEmployees('');
                                  }
                                }
                              },
                            ),
                          ),
                          if (_audienceType == 'Department') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                              ),
                            ),
                          ] else if (_audienceType == 'Role') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
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
                                  return DropdownMenuItem(value: roleName, child: Text(roleName));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _targetValueController.text = val);
                                },
                              ),
                            ),
                          ] else if (!isSpecificEmployee && _audienceType != 'Entire Institute') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _targetValueController,
                                decoration: InputDecoration(
                                  labelText: 'Specific $_audienceType',
                                  hintText: 'e.g. Target group...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Employee Search and Multi-Select Area
                      if (isSpecificEmployee) ...[
                        // Search Box
                        TextFormField(
                          controller: _employeeSearchController,
                          decoration: InputDecoration(
                            labelText: 'Search Employee / Staff to Assign *',
                            hintText: 'Type name, email, department, or role...',
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
                                          _searchEmployees('');
                                        },
                                      )
                                    : null),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: _onEmployeeSearchChanged,
                        ),
                        const SizedBox(height: 10),

                        // Selected Employees Chips
                        if (_selectedEmployees.isNotEmpty) ...[
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
                                      'Selected Signees (${_selectedEmployees.length})',
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
                                  runSpacing: 6,
                                  children: _selectedEmployees.map((emp) {
                                    final name = emp['full_name'] ?? 'Staff';
                                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                                    return Chip(
                                      avatar: CircleAvatar(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      label: Text(
                                        '$name (${emp['department'] ?? 'General'})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                                      onDeleted: () => _toggleEmployee(emp),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      side: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Search Results List
                        Material(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 180),
                            child: _employeeSearchResults.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        _isSearchingEmployees ? 'Searching employees...' : 'No staff found matching query.',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: _employeeSearchResults.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    itemBuilder: (context, idx) {
                                      final emp = _employeeSearchResults[idx];
                                      final isSelected = _selectedEmployees.any((e) => e['id'] == emp['id']);
                                      final name = emp['full_name'] ?? 'Staff';
                                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                                      return Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          dense: true,
                                          leading: CircleAvatar(
                                            radius: 14,
                                            backgroundColor: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B).withValues(alpha: 0.2),
                                            child: Text(
                                              initial,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              fontSize: 13,
                                              color: isSelected ? const Color(0xFF4F46E5) : null,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${emp['email']} · ${emp['department'] ?? 'General'} · ${emp['designation'] ?? emp['role'] ?? 'Staff'}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                          trailing: Checkbox(
                                            value: isSelected,
                                            activeColor: const Color(0xFF4F46E5),
                                            onChanged: (_) => _toggleEmployee(emp),
                                          ),
                                          onTap: () => _toggleEmployee(emp),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Deadline Date Picker
                      InkWell(
                        onTap: _pickDeadline,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Acknowledgement Deadline *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                          ),
                          child: Text(_dateFormat.format(_deadline)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notification message
                      TextFormField(
                        controller: _messageController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Notification Message to Employees',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isMandatory,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _isMandatory = v ?? true),
                              ),
                              const Text('Mandatory sign-off requirement', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _sendInAppNotification,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _sendInAppNotification = v ?? true),
                              ),
                              const Text('Send in-app notification', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _sendEmail,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (v) => setState(() => _sendEmail = v ?? true),
                              ),
                              const Text('Send email notification to employees', style: TextStyle(fontSize: 13)),
                            ],
                          ),
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
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting
                          ? 'Dispatching...'
                          : (isSpecificEmployee && _selectedEmployees.isNotEmpty
                              ? 'Dispatch to ${_selectedEmployees.length} Signee${_selectedEmployees.length > 1 ? "s" : ""}'
                              : 'Dispatch Request'),
                      style: const TextStyle(color: Colors.white),
                    ),
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
        ),
      ),
    );
  }
}
