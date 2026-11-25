import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class AssignHostelStaffDialog extends ConsumerStatefulWidget {
  const AssignHostelStaffDialog({super.key});

  @override
  ConsumerState<AssignHostelStaffDialog> createState() => _AssignHostelStaffDialogState();
}

class _AssignHostelStaffDialogState extends ConsumerState<AssignHostelStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedProfileId;
  EligibleStaffProfileItem? _selectedProfile;
  String? _selectedHostelId;
  String _selectedRole = 'Hostel Warden';
  final _areaController = TextEditingController(text: 'Overall');
  final _shiftController = TextEditingController(text: '6:00 AM - 10:00 PM');
  final _supervisorController = TextEditingController(text: 'Hostel Administrator');
  final _notesController = TextEditingController();
  DateTime _startDate = DateTime.now();

  final _searchController = TextEditingController();
  List<EligibleStaffProfileItem> _eligibleProfiles = [];
  bool _isLoadingProfiles = false;
  bool _isSubmitting = false;

  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _fetchEligibleProfiles('');
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
        if (!_roles.contains(_selectedRole) && _roles.isNotEmpty) {
          _selectedRole = _roles.first;
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEligibleProfiles(String query) async {
    setState(() => _isLoadingProfiles = true);
    try {
      final profiles = await ref.read(hostelProvider.notifier).service.getEligibleStaffProfiles(
        search: query,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _eligibleProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use hostels from structureTree or default buildings
    final buildings = state.structureTree;
    if (_selectedHostelId == null && buildings.isNotEmpty) {
      _selectedHostelId = buildings.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Staff Member to Hostel',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Select an existing staff profile and assign operational duties',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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

              // Form Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Staff Profile Picker
                        const Text(
                          'Select Staff Profile *',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        if (_selectedProfile != null)
                          _buildSelectedProfileCard(isDark)
                        else
                          _buildProfilePickerField(isDark),

                        const SizedBox(height: 16),

                        // 2. Hostel Selection
                        const Text(
                          'Hostel Building *',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: AppSearchableDropdown<String>.fromMenuItems(
                              value: _selectedHostelId,
                              isExpanded: true,
                              hint: const Text('Select Hostel Building'),
                              items: buildings.map((b) {
                                return DropdownMenuItem<String>(
                                  value: b.id,
                                  child: Text(b.name, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedHostelId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Hostel Duty Role & Area
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hostel Role *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
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
                                        items: _roles.map((r) {
                                          return DropdownMenuItem<String>(
                                            value: r,
                                            child: Text(r, style: const TextStyle(fontSize: 13)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedRole = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Assigned Area *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _areaController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Overall, 1st Floor',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. Shift Timings & Supervisor
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shift Timings *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _shiftController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 6:00 AM - 10:00 PM',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reporting To',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _supervisorController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Hostel Administrator',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      isDense: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Start Date Picker
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Effective Start Date',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (picked != null) setState(() => _startDate = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 6. Responsibilities / Notes
                        const Text(
                          'Responsibilities / Specific Duty Notes',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Add duties, areas of coverage, or special instructions...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(12),
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
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAssignment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm Assignment', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedProfileCard(bool isDark) {
    final p = _selectedProfile!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2563EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: p.avatarUrl != null && p.avatarUrl!.isNotEmpty ? NetworkImage(p.avatarUrl!) : null,
            backgroundColor: const Color(0xFFEFF6FF),
            child: p.avatarUrl == null || p.avatarUrl!.isEmpty
                ? Text(p.fullName.isNotEmpty ? p.fullName[0] : 'S', style: const TextStyle(color: Color(0xFF2563EB)))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Role: ${p.role} · ID: ${p.employeeId ?? '-'} · Contact: ${p.phone ?? '-'}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedProfile = null;
                _selectedProfileId = null;
              });
            },
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePickerField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search staff by name or employee ID...',
            prefixIcon: const Icon(Icons.search, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            isDense: true,
          ),
          onChanged: (val) => _fetchEligibleProfiles(val),
        ),
        const SizedBox(height: 6),
        Container(
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoadingProfiles
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _eligibleProfiles.isEmpty
                  ? const Center(child: Text('No eligible staff profiles found', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))))
                  : ListView.builder(
                      itemCount: _eligibleProfiles.length,
                      itemBuilder: (context, i) {
                        final p = _eligibleProfiles[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(p.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${p.role} · ${p.employeeId ?? ""} · ${p.phone ?? ""}', style: const TextStyle(fontSize: 11.5)),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                          onTap: () {
                            setState(() {
                              _selectedProfile = p;
                              _selectedProfileId = p.id;
                            });
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _submitAssignment() async {
    if (_selectedProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff profile first.')),
      );
      return;
    }
    if (_selectedHostelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel building.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'profile_id': _selectedProfileId,
      'hostel_id': _selectedHostelId,
      'academic_year': ref.read(hostelProvider).selectedAcademicYear,
      'hostel_role': _selectedRole,
      'assigned_area_text': _areaController.text.trim(),
      'shift_timings': _shiftController.text.trim(),
      'supervisor_name': _supervisorController.text.trim(),
      'start_date': '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
      'responsibilities': _notesController.text.trim(),
      'areas': [
        {
          'area_name': _areaController.text.trim(),
          'badge_label': 'Primary',
          'is_primary': true,
        }
      ],
    };

    final success = await ref.read(hostelProvider.notifier).assignStaff(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }
}
