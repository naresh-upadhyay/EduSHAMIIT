import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/safety_compliance_models.dart';
import '../../../providers/safety_compliance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class LogInspectionDialog extends ConsumerStatefulWidget {
  final SafetyInspectionItem? existingInspection;

  const LogInspectionDialog({super.key, this.existingInspection});

  @override
  ConsumerState<LogInspectionDialog> createState() => _LogInspectionDialogState();
}

class _LogInspectionDialogState extends ConsumerState<LogInspectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _inspectorNameController;
  late TextEditingController _inspectorRoleController;
  late TextEditingController _scoreController;
  late TextEditingController _findingsController;

  String _category = 'Fire Safety';
  String _status = 'Passed';
  DateTime _inspectionDate = DateTime.now();

  bool _isSaving = false;
  bool _isCustomInspector = false;
  bool _isCustomRole = false;

  String? _selectedInspectorUserId;
  String? _selectedRole;

  List<Map<String, dynamic>> _staffUsers = [];
  List<Map<String, dynamic>> _appRoles = [];
  List<String> _categories = [];
  List<String> _statuses = [];

  @override
  void initState() {
    super.initState();
    final item = widget.existingInspection;
    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.locationDisplay ?? 'Academic Block / All Floors');
    _inspectorNameController = TextEditingController(text: item?.inspectorName ?? '');
    _inspectorRoleController = TextEditingController(text: item?.inspectorRole ?? 'Safety Officer');
    _scoreController = TextEditingController(text: '${item?.complianceScore ?? 96.0}');
    _findingsController = TextEditingController(text: item?.findings ?? '');

    _selectedInspectorUserId = item?.inspectorUserId;
    if (item != null) {
      _category = item.category;
      _status = item.status;
      _inspectionDate = item.inspectionDate;
      _selectedRole = item.inspectorRole;
    }

    _categories = CampusLookupHelper.instance.getImmediateLabels('INSPECTION_CATEGORY');
    _statuses = CampusLookupHelper.instance.getImmediateLabels('INSPECTION_STATUS');

    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      CampusLookupHelper.instance.getStaffUsers(),
      CampusLookupHelper.instance.getAppRoles(),
      CampusLookupHelper.instance.getLookupLabels('INSPECTION_CATEGORY'),
      CampusLookupHelper.instance.getLookupLabels('INSPECTION_STATUS'),
    ]);

    if (!mounted) return;

    final users = results[0] as List<Map<String, dynamic>>;
    final roles = results[1] as List<Map<String, dynamic>>;
    final cats = results[2] as List<String>;
    final stats = results[3] as List<String>;

    setState(() {
      _staffUsers = users;
      _appRoles = roles;
      if (cats.isNotEmpty) {
        _categories = cats;
        if (!_categories.contains(_category)) _category = _categories.first;
      }
      if (stats.isNotEmpty) {
        _statuses = stats;
        if (!_statuses.contains(_status)) _status = _statuses.first;
      }

      if (_selectedInspectorUserId != null && _selectedInspectorUserId!.isNotEmpty) {
        final match = _staffUsers.where((u) => u['id']?.toString() == _selectedInspectorUserId).firstOrNull;
        if (match != null) {
          _selectedInspectorUserId = match['id']?.toString();
          if (_inspectorNameController.text.isEmpty) {
            _inspectorNameController.text = (match['full_name'] ?? match['name'] ?? '').toString();
          }
        } else {
          _isCustomInspector = true;
        }
      } else if (widget.existingInspection == null) {
        if (_staffUsers.isNotEmpty && _inspectorNameController.text.isEmpty) {
          final first = _staffUsers.first;
          _selectedInspectorUserId = first['id']?.toString();
          _inspectorNameController.text = (first['full_name'] ?? first['name'] ?? '').toString();
          final uRole = (first['role'] ?? 'Safety Officer').toString();
          _selectedRole = _matchRole(uRole, _appRoles);
          _inspectorRoleController.text = _selectedRole ?? uRole;
        }
      } else {
        final match = _staffUsers.where((u) =>
            (u['full_name'] ?? '').toString().trim().toLowerCase() == _inspectorNameController.text.trim().toLowerCase()
        ).firstOrNull;
        if (match != null) {
          _selectedInspectorUserId = match['id']?.toString();
        } else {
          _isCustomInspector = true;
        }
      }
    });
  }

  String _matchRole(String roleStr, List<Map<String, dynamic>> roles) {
    for (final r in roles) {
      final dName = (r['display_name'] ?? '').toString().trim();
      final name = (r['name'] ?? '').toString().trim();
      if (dName.toLowerCase() == roleStr.toLowerCase() || name.toLowerCase() == roleStr.toLowerCase()) {
        return dName.isNotEmpty ? dName : name;
      }
    }
    return roleStr;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _inspectorNameController.dispose();
    _inspectorRoleController.dispose();
    _scoreController.dispose();
    _findingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fact_check_rounded, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingInspection != null ? 'Edit Safety Inspection' : 'Log Safety & Quality Inspection',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inspection Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter inspection title' : null,
                        decoration: _inputDeco('e.g. Quarterly Extinguisher & Fire Hose Reel Audit', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Category & Status Row (from Lookup Keys & Values)
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(width: 4),
                                  Text('(Lookup Key)', style: TextStyle(fontSize: 10, color: textMuted)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              AppSearchableDropdownFormField<String>.fromMenuItems(
                                isExpanded: true,
                                value: _categories.contains(_category) ? _category : (_categories.isNotEmpty ? _categories.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _categories
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _category = v ?? _category),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Inspection Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(width: 4),
                                  Text('(Lookup Key)', style: TextStyle(fontSize: 10, color: textMuted)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              AppSearchableDropdownFormField<String>.fromMenuItems(
                                isExpanded: true,
                                value: _statuses.contains(_status) ? _status : (_statuses.isNotEmpty ? _statuses.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _statuses
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v ?? _status),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location & Score Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location Display *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _locationController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter inspection location' : null,
                                decoration: _inputDeco('e.g. Science Block / Labs', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Score (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _scoreController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: _inputDeco('95.0', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Section Header: Inspector Details
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(
                              'Inspector & Role Assignment (From User Profiles & Roles Master)',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 1. Inspector User Selection (From profiles table)
                      Text('Assigned Inspector (User from User Management / profiles) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        isExpanded: true,
                        value: _isCustomInspector ? 'CUSTOM' : _selectedInspectorUserId,
                        decoration: _inputDeco('Select inspector profile', borderColor, isDark),
                        dropdownColor: dialogBg,
                        items: [
                          if (_staffUsers.isNotEmpty)
                            ..._staffUsers.map((u) {
                              final uid = u['id']?.toString() ?? '';
                              final name = (u['full_name'] ?? u['name'] ?? 'User').toString();
                              final role = (u['role'] ?? 'Staff').toString();
                              final email = (u['email'] ?? '').toString();
                              final label = email.isNotEmpty ? '$name ($role • $email)' : '$name ($role)';
                              return DropdownMenuItem<String>(
                                value: uid,
                                child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary)),
                              );
                            }),
                          DropdownMenuItem<String>(
                            value: 'CUSTOM',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text('Other / External Inspector (Manual Entry)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == 'CUSTOM') {
                            setState(() {
                              _isCustomInspector = true;
                              _selectedInspectorUserId = null;
                            });
                          } else if (val != null) {
                            final match = _staffUsers.where((u) => u['id']?.toString() == val).firstOrNull;
                            setState(() {
                              _isCustomInspector = false;
                              _selectedInspectorUserId = val;
                              if (match != null) {
                                _inspectorNameController.text = (match['full_name'] ?? match['name'] ?? '').toString();
                                final uRole = (match['role'] ?? 'Safety Officer').toString();
                                _selectedRole = _matchRole(uRole, _appRoles);
                                _inspectorRoleController.text = _selectedRole ?? uRole;
                              }
                            });
                          }
                        },
                      ),
                      if (_isCustomInspector) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _inspectorNameController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter external inspector name' : null,
                          decoration: _inputDeco('Enter external inspector full name...', borderColor, isDark),
                          style: TextStyle(fontSize: 12.5, color: textPrimary),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // 2. Inspector Role Selection (From app_roles table)
                      Row(
                        children: [
                          Text('Inspector Role (From Role Management / app_roles) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                          const Spacer(),
                          InkWell(
                            onTap: () => setState(() => _isCustomRole = !_isCustomRole),
                            child: Text(
                              _isCustomRole ? 'Choose standard role' : '+ Custom Role',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (!_isCustomRole)
                        AppSearchableDropdownFormField<String>.fromMenuItems(
                          isExpanded: true,
                          value: _getRoleDropdownValue(),
                          decoration: _inputDeco('Select role from app_roles', borderColor, isDark),
                          dropdownColor: dialogBg,
                          items: [
                            ..._appRoles.map((r) {
                              final dName = (r['display_name'] ?? r['name'] ?? '').toString();
                              return DropdownMenuItem<String>(
                                value: dName,
                                child: Text(dName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary)),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: 'Safety Officer',
                              child: Text('Safety Officer', style: TextStyle(fontSize: 12)),
                            ),
                            const DropdownMenuItem<String>(
                              value: 'Fire Marshal',
                              child: Text('Fire Marshal', style: TextStyle(fontSize: 12)),
                            ),
                            const DropdownMenuItem<String>(
                              value: 'External Auditor',
                              child: Text('External Auditor', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedRole = val;
                                _inspectorRoleController.text = val;
                              });
                            }
                          },
                        )
                      else
                        TextFormField(
                          controller: _inspectorRoleController,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter role title' : null,
                          decoration: _inputDeco('e.g. FSSAI Certified Food Inspector', borderColor, isDark),
                          style: TextStyle(fontSize: 12.5, color: textPrimary),
                        ),
                      const SizedBox(height: 14),

                      // Findings & Audit Observations
                      Text('Audit Findings & Action Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _findingsController,
                        maxLines: 3,
                        decoration: _inputDeco('Enter physical check findings, pressure readings, test outcomes...', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                widget.existingInspection != null ? 'Save Inspection' : 'Create Inspection',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getRoleDropdownValue() {
    if (_selectedRole != null) {
      final existsInRoles = _appRoles.any((r) => (r['display_name'] ?? r['name']) == _selectedRole);
      final existsInDefaults = ['Safety Officer', 'Fire Marshal', 'External Auditor'].contains(_selectedRole);
      if (existsInRoles || existsInDefaults) return _selectedRole;
    }
    if (_inspectorRoleController.text.isNotEmpty) {
      final existsInRoles = _appRoles.any((r) => (r['display_name'] ?? r['name']) == _inspectorRoleController.text);
      final existsInDefaults = ['Safety Officer', 'Fire Marshal', 'External Auditor'].contains(_inspectorRoleController.text);
      if (existsInRoles || existsInDefaults) return _inspectorRoleController.text;
    }
    return 'Safety Officer';
  }

  void _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final inspectorRoleVal = _isCustomRole
        ? _inspectorRoleController.text.trim()
        : (_selectedRole ?? _inspectorRoleController.text.trim());

    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'location_display': _locationController.text.trim(),
      'inspector_user_id': _selectedInspectorUserId,
      'inspector_name': _inspectorNameController.text.trim(),
      'inspector_role': inspectorRoleVal.isNotEmpty ? inspectorRoleVal : 'Safety Officer',
      'status': _status,
      'compliance_score': double.tryParse(_scoreController.text) ?? 95.0,
      'findings': _findingsController.text.trim(),
      'inspection_date': '${_inspectionDate.year}-${_inspectionDate.month.toString().padLeft(2, '0')}-${_inspectionDate.day.toString().padLeft(2, '0')}',
    };

    try {
      final notifier = ref.read(safetyComplianceProvider.notifier);
      final success = await notifier.saveInspection(payload, inspectionId: widget.existingInspection?.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save inspection. Please verify details.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving inspection: $e')),
        );
      }
    }
  }

  Widget _responsiveRow(BuildContext context, List<Widget> children) {
    final isMobile = MediaQuery.of(context).size.width < 550;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  InputDecoration _inputDeco(String hint, Color border, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: border)),
    );
  }
}
