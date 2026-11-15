import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';

class AssignComplaintDialog extends ConsumerStatefulWidget {
  final String complaintId;
  final String? currentAssignee;

  const AssignComplaintDialog({
    super.key,
    required this.complaintId,
    this.currentAssignee,
  });

  @override
  ConsumerState<AssignComplaintDialog> createState() => _AssignComplaintDialogState();
}

class _AssignComplaintDialogState extends ConsumerState<AssignComplaintDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedStaffId;
  String _selectedRole = 'PRIMARY';
  bool _isSubmitting = false;

  static const List<Map<String, String>> _fallbackStaffMembers = [
    {
      'id': '41000003-0000-0000-0000-000000000003',
      'name': 'Mr. Ramesh Babu',
      'role': 'Maintenance Staff (Plumber)',
      'department': 'Plumbing & Water Supply',
    },
    {
      'id': '41000001-0000-0000-0000-000000000001',
      'name': 'Mr. Suresh Kumar',
      'role': 'Senior Electrician / Warden',
      'department': 'Electrical & Power',
    },
    {
      'id': '41000005-0000-0000-0000-000000000005',
      'name': 'Mr. Karthik Reddy',
      'role': 'Carpenter & Infrastructure',
      'department': 'Furniture & Carpentry',
    },
    {
      'id': '41000006-0000-0000-0000-000000000006',
      'name': 'Ms. Sneha Iyer',
      'role': 'Housekeeping Supervisor',
      'department': 'Housekeeping & Sanitation',
    },
    {
      'id': '41000002-0000-0000-0000-000000000002',
      'name': 'Mrs. Priya Nair',
      'role': 'Hostel Warden',
      'department': 'Hostel Administration',
    },
    {
      'id': '41000009-0000-0000-0000-000000000009',
      'name': 'Mr. Ravi Shankar',
      'role': 'HVAC Technician',
      'department': 'AC & Heating',
    },
    {
      'id': '41000007-0000-0000-0000-000000000007',
      'name': 'Mr. Mohammed Arif',
      'role': 'Security & Network Officer',
      'department': 'WiFi & Networking',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedStaffId = _fallbackStaffMembers.first['id'];
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _resolveStaffList() {
    final staffRoster = ref.read(hostelProvider).staffRoster;
    if (staffRoster.isNotEmpty) {
      final list = <Map<String, String>>[];
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      for (int i = 0; i < staffRoster.length; i++) {
        final s = staffRoster[i];
        final id = uuidRegex.hasMatch(s.profileId)
            ? s.profileId
            : (i < _fallbackStaffMembers.length ? _fallbackStaffMembers[i]['id']! : _fallbackStaffMembers.first['id']!);
        list.add({
          'id': id,
          'name': s.name,
          'role': s.role,
          'department': s.assignedArea.isNotEmpty ? s.assignedArea : s.hostelName,
        });
      }
      return list;
    }
    return _fallbackStaffMembers;
  }

  Future<void> _submit(List<Map<String, String>> staffList) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final selectedStaff = staffList.firstWhere(
      (s) => s['id'] == _selectedStaffId,
      orElse: () => staffList.first,
    );

    final success = await ref.read(hostelProvider.notifier).assignComplaint(
      widget.complaintId,
      selectedStaff['id']!,
      userName: selectedStaff['name'],
      role: selectedStaff['role'],
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < 600;

    final rawStaffList = _resolveStaffList();
    final seenIds = <String>{};
    final staffList = rawStaffList.where((s) => seenIds.add(s['id']!)).toList();
    if (_selectedStaffId == null || !staffList.any((s) => s['id'] == _selectedStaffId)) {
      _selectedStaffId = staffList.isNotEmpty ? staffList.first['id'] : null;
    }

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.95 : 520,
          maxHeight: screenHeight * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentAssignee != null ? 'Reassign Complaint' : 'Assign Complaint',
                          style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        if (widget.currentAssignee != null)
                          Text(
                            'Current assignee: ${widget.currentAssignee}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Staff / Technician *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStaffId,
                        isExpanded: true,
                        dropdownColor: cardBg,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return staffList.map<Widget>((s) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${s['name']} — ${s['role']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                              ),
                            );
                          }).toList();
                        },
                        items: staffList.map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  s['name']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                                ),
                                Text(
                                  s['role']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedStaffId = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Assignment Role
                      Text('Assignment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      if (isMobile)
                        Column(
                          children: [
                            RadioListTile<String>(
                              value: 'PRIMARY',
                              groupValue: _selectedRole,
                              activeColor: const Color(0xFF2563EB),
                              title: Text('Primary Assignee', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _selectedRole = v!),
                            ),
                            RadioListTile<String>(
                              value: 'SUPPORT',
                              groupValue: _selectedRole,
                              activeColor: const Color(0xFF2563EB),
                              title: Text('Supporting Staff', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setState(() => _selectedRole = v!),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'PRIMARY',
                                groupValue: _selectedRole,
                                activeColor: const Color(0xFF2563EB),
                                title: Text('Primary Assignee', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setState(() => _selectedRole = v!),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'SUPPORT',
                                groupValue: _selectedRole,
                                activeColor: const Color(0xFF2563EB),
                                title: Text('Supporting Staff', style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (v) => setState(() => _selectedRole = v!),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // Assignment Instructions
                      Text('Assignment Notes / Instructions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Inspect washbasin seal, replace gasket if damaged...',
                          hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: borderColor),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submit(staffList),
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Assigning...' : 'Assign Staff',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
