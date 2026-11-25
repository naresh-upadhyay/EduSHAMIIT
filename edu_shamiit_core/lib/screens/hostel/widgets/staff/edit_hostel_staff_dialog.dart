import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class EditHostelStaffDialog extends ConsumerStatefulWidget {
  final HostelStaffRosterItem staff;

  const EditHostelStaffDialog({super.key, required this.staff});

  @override
  ConsumerState<EditHostelStaffDialog> createState() => _EditHostelStaffDialogState();
}

class _EditHostelStaffDialogState extends ConsumerState<EditHostelStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedRole;
  late TextEditingController _areaController;
  late TextEditingController _shiftController;
  late TextEditingController _supervisorController;
  late TextEditingController _notesController;
  String _selectedStatus = 'ACTIVE';
  bool _isSubmitting = false;

  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.staff.role;
    _areaController = TextEditingController(text: widget.staff.assignedArea);
    _shiftController = TextEditingController(text: widget.staff.shiftTimings.isNotEmpty ? widget.staff.shiftTimings : '6:00 AM - 10:00 PM');
    _supervisorController = TextEditingController(text: 'Hostel Administrator');
    _notesController = TextEditingController();
    _selectedStatus = widget.staff.status.toUpperCase().contains('LEAVE') ? 'ON_LEAVE' : 'ACTIVE';
    _loadRolesFromLookup();
  }

  Future<void> _loadRolesFromLookup() async {
    final roles = await HostelLookupHelper.instance.getLookupLabels('HOSTEL_STAFF_ROLE');
    if (mounted) {
      setState(() {
        _roles = roles.isNotEmpty ? roles : [
          'Hostel Warden',
          'Chief Warden',
          'Assistant Warden',
          'Hostel Supervisor',
          'Hostel Caretaker',
          'Security Guard',
          'Housekeeping / Cleaning Staff',
          'Mess Incharge',
          'Maintenance Technician'
        ];
        if (!_roles.contains(_selectedRole)) {
          _roles.insert(0, _selectedRole);
        }
      });
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    _shiftController.dispose();
    _supervisorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Staff Assignment - ${widget.staff.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Hostel: ${widget.staff.hostelName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role
                        const Text('Hostel Role *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: AppSearchableDropdown<String>.fromMenuItems(
                              value: _selectedRole,
                              isExpanded: true,
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedRole = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Assigned Area
                        const Text('Assigned Area *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _areaController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Shift Timings
                        const Text('Shift Timings *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _shiftController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Dropdown
                        const Text('Duty Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: AppSearchableDropdown<String>.fromMenuItems(
                              value: _selectedStatus,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'ACTIVE', child: Text('Active (On Duty)')),
                                DropdownMenuItem(value: 'ON_LEAVE', child: Text('On Leave')),
                                DropdownMenuItem(value: 'PENDING', child: Text('Pending Assignment')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedStatus = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Supervisor
                        const Text('Supervisor / Reporting Officer', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _supervisorController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'assignment_id': widget.staff.assignmentId,
      'hostel_role': _selectedRole,
      'assigned_area_text': _areaController.text.trim(),
      'shift_timings': _shiftController.text.trim(),
      'supervisor_name': _supervisorController.text.trim(),
      'assignment_status': _selectedStatus,
      'duty_status': _selectedStatus == 'ON_LEAVE' ? 'ON_LEAVE' : 'ON_DUTY',
    };

    final success = await ref.read(hostelProvider.notifier).updateStaffAssignment(
      widget.staff.assignmentId,
      payload,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop();
    }
  }
}
