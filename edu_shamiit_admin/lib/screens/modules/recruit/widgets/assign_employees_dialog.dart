import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class AssignEmployeesDialog extends StatefulWidget {
  final String programId;
  final String programTitle;
  final VoidCallback onAssigned;

  const AssignEmployeesDialog({
    super.key,
    required this.programId,
    required this.programTitle,
    required this.onAssigned,
  });

  @override
  State<AssignEmployeesDialog> createState() => _AssignEmployeesDialogState();
}

class _AssignEmployeesDialogState extends State<AssignEmployeesDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _employees = [];
  final Set<String> _selectedEmployeeIds = {};
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  bool _isMandatory = false;

  List<String> _departments = ['All', ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT')];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _fetchEmployees();
    _loadLookups(true);
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    super.dispose();
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departments = ['All', ...depts];
        if (!_departments.contains(_selectedDepartment)) {
          _selectedDepartment = 'All';
        }
      });
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final queryParams = <String>[];
      if (_selectedDepartment != 'All') queryParams.add('department=$_selectedDepartment');
      if (_searchQuery.isNotEmpty) queryParams.add('search=$_searchQuery');
      final qStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await _api.get('/training/employees$qStr', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _employees = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEmployeeIds.length == _employees.length) {
        _selectedEmployeeIds.clear();
      } else {
        _selectedEmployeeIds.clear();
        for (var e in _employees) {
          _selectedEmployeeIds.add(e['id'].toString());
        }
      }
    });
  }

  Future<void> _submitAssignment() async {
    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee to assign.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'employee_ids': _selectedEmployeeIds.toList(),
        'is_mandatory': _isMandatory,
      };
      final res = await _api.post('/training/programs/${widget.programId}/assign', payload);
      if (res['success'] == true) {
        widget.onAssigned();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Employees assigned successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning employees: $e'), backgroundColor: Colors.red),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 640,
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Employees to Training',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.programTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Search & Department Filter Bar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by employee name or ID...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      _searchQuery = v.trim();
                      _fetchEmployees();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _departments.contains(_selectedDepartment) ? _selectedDepartment : 'All',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) {
                      setState(() => _selectedDepartment = v ?? 'All');
                      _fetchEmployees();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Select All & Mandatory Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _employees.isNotEmpty && _selectedEmployeeIds.length == _employees.length,
                      onChanged: (v) => _toggleSelectAll(),
                      activeColor: const Color(0xFF4F46E5),
                    ),
                    GestureDetector(
                      onTap: _toggleSelectAll,
                      child: Text(
                        'Select All (${_employees.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    if (_selectedEmployeeIds.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedEmployeeIds.length} Selected',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    const Text('Mandatory for these staff:', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isMandatory,
                      activeThumbColor: const Color(0xFF4F46E5),
                      onChanged: (v) => setState(() => _isMandatory = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // Employee List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _employees.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_off_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No employees match the criteria.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _employees.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final emp = _employees[i];
                            final id = emp['id'].toString();
                            final isSelected = _selectedEmployeeIds.contains(id);
                            final name = emp['full_name'] ?? 'Staff Member';
                            final code = emp['employee_code'] ?? 'Emp--';
                            final dept = emp['department'] ?? 'Academics';
                            final desig = emp['designation'] ?? 'Staff';

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedEmployeeIds.add(id);
                                  } else {
                                    _selectedEmployeeIds.remove(id);
                                  }
                                });
                              },
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                  style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('$code • $dept • $desig', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            );
                          },
                        ),
            ),

            // Actions Footer
            const Divider(height: 1),
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
                  onPressed: _isSubmitting || _selectedEmployeeIds.isEmpty ? null : _submitAssignment,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16, color: Colors.white),
                  label: Text(
                    'Assign Selected (${_selectedEmployeeIds.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
