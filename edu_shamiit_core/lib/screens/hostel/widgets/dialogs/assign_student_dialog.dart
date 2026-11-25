import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class AssignStudentDialog extends ConsumerStatefulWidget {
  final HostelRoomDetail? room;
  final HostelRoomItem? roomItem;
  final HostelRoomItem? preselectedRoomItem;
  final String? preselectedRoomId;
  final HostelBed? preselectedBed;

  const AssignStudentDialog({
    super.key,
    this.room,
    this.roomItem,
    this.preselectedRoomItem,
    this.preselectedRoomId,
    this.preselectedBed,
  }) : assert(room != null || roomItem != null || preselectedRoomItem != null || preselectedRoomId != null);

  @override
  ConsumerState<AssignStudentDialog> createState() => _AssignStudentDialogState();
}

class _AssignStudentDialogState extends ConsumerState<AssignStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentSearchController = TextEditingController();
  final TextEditingController _depositController = TextEditingController(text: '5000');
  final TextEditingController _monthlyRentController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _selectedBedId;
  DateTime _checkInDate = DateTime.now();
  bool _autoGenerateFeeInvoice = true;
  bool _isSubmitting = false;
  HostelRoomDetail? _loadedRoomDetail;
  bool _isLoadingDetail = false;

  HostelRoomDetail? get _effectiveRoom => widget.room ?? _loadedRoomDetail;

  void _initBedAndRent() {
    final r = _effectiveRoom;
    if (r == null) return;
    _selectedBedId = widget.preselectedBed?.id;
    _monthlyRentController.text = '${widget.preselectedBed?.monthlyPrice?.toInt() ?? r.monthlyFee.toInt()}';
    if (_selectedBedId == null) {
      final availBeds = r.beds
          .where((b) => b.isAvailable || b.status.toUpperCase() == 'AVAILABLE')
          .toList();
      if (availBeds.isNotEmpty) {
        _selectedBedId = availBeds.first.id;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final targetItem = widget.roomItem ?? widget.preselectedRoomItem;
    final targetId = widget.room?.id ?? targetItem?.id ?? widget.preselectedRoomId;

    if (widget.room == null && targetId != null) {
      _isLoadingDetail = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final d = await ref.read(hostelProvider.notifier).service.getRoomDetail(targetId);
        if (mounted) {
          setState(() {
            _loadedRoomDetail = d;
            _isLoadingDetail = false;
            _initBedAndRent();
          });
        }
      });
    } else {
      _initBedAndRent();
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    _depositController.dispose();
    _monthlyRentController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _searchStudents(String q) async {
    if (q.trim().length < 2) return;
    setState(() => _isSearching = true);
    final notifier = ref.read(hostelProvider.notifier);
    final results = await notifier.service.searchStudents(q.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final r = _effectiveRoom;

    if (_isLoadingDetail || r == null) {
      return AlertDialog(
        title: Text('Assign Student to Room ${widget.roomItem?.roomNumber ?? ""}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const SizedBox(
          width: 480,
          height: 140,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final availableBeds = r.beds.where((b) {
      return b.isAvailable || b.status.toUpperCase() == 'AVAILABLE' || b.id == widget.preselectedBed?.id;
    }).toList();

    return AlertDialog(
      title: Text('Assign Student to Room ${r.roomNumber}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student selection / search
                const Text('Student *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (_selectedStudent != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade200,
                          child: Text(
                            (_selectedStudent!['full_name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStudent!['full_name'] ?? 'Unnamed',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                'Adm: ${_selectedStudent!['admission_number'] ?? 'N/A'} • Grade: ${_selectedStudent!['grade'] ?? 'N/A'}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _selectedStudent = null),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _studentSearchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by student name or admission number...',
                            prefixIcon: Icon(Icons.search, size: 18),
                            isDense: true,
                          ),
                          onFieldSubmitted: _searchStudents,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _searchStudents(_studentSearchController.text),
                        child: _isSearching
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Search'),
                      ),
                    ],
                  ),
                  if (_searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _searchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(s['full_name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            subtitle: Text('Adm: ${s['admission_number'] ?? 'N/A'} | ${s['gender'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              setState(() {
                                _selectedStudent = s;
                                _searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  isExpanded: true,
                  initialValue: availableBeds.any((b) => b.id == _selectedBedId) ? _selectedBedId : (availableBeds.isNotEmpty ? availableBeds.first.id : null),
                  decoration: const InputDecoration(labelText: 'Select Bed *'),
                  items: availableBeds.map((b) {
                    return DropdownMenuItem(
                      value: b.id,
                      child: Text('${b.bedNumber} (${b.bedType}) - ₹${b.monthlyPrice?.toInt() ?? 6000}/mo', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedBedId = v),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please select a bed' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _depositController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Security Deposit (₹)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _monthlyRentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monthly Rent (₹)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _checkInDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _checkInDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Check-in Date'),
                          child: Text(
                            '${_checkInDate.year}-${_checkInDate.month.toString().padLeft(2, '0')}-${_checkInDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Academic Year'),
                        child: Text(state.selectedAcademicYear, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks / Notes', hintText: 'Special accommodation requirements...'),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _autoGenerateFeeInvoice,
                  onChanged: (val) => setState(() => _autoGenerateFeeInvoice = val ?? true),
                  title: const Text('Auto-generate Admission Fee Invoice', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enrolls student into fee system with deposit & first month rent invoice', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF2563EB),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedStudent == null ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isSubmitting = true);

            final depositVal = double.tryParse(_depositController.text) ?? 5000.0;
            final rentVal = double.tryParse(_monthlyRentController.text) ?? 6000.0;

            final payload = {
              'student_id': _selectedStudent!['id'],
              'building_id': r.buildingId,
              'floor_id': r.floorId,
              'room_id': r.id,
              'bed_id': _selectedBedId,
              'academic_year': state.selectedAcademicYear,
              'check_in_date': '${_checkInDate.year}-${_checkInDate.month.toString().padLeft(2, '0')}-${_checkInDate.day.toString().padLeft(2, '0')}',
              'deposit_amount': depositVal,
              'monthly_rent': rentVal,
              'remarks': _remarksController.text.trim(),
            };

            final navigator = Navigator.of(context);
            final res = await notifier.service.assignStudent(payload);
            if (mounted) {
              setState(() => _isSubmitting = false);
              if (res['success'] == true) {
                navigator.pop();
                notifier.showSuccess('Student assigned successfully to ${r.roomNumber}');

                // Auto-generate initial admission & deposit invoice if option was selected
                if (_autoGenerateFeeInvoice) {
                  try {
                    final dueDate = DateTime.now().add(const Duration(days: 7));
                    final dueDateStr = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
                    await notifier.generateSingleInvoice({
                      'student_id': _selectedStudent!['id'],
                      'academic_year': state.selectedAcademicYear,
                      'due_date': dueDateStr,
                      'invoice_type': 'HOSTEL_ADMISSION',
                      'title': 'Hostel Admission & First Month Fee',
                      'total_amount': depositVal + rentVal,
                      'items': [
                        {'title': 'Hostel Security Deposit (Refundable)', 'amount': depositVal},
                        {'title': 'Hostel Monthly Rent (${r.roomNumber})', 'amount': rentVal},
                      ],
                      'remarks': 'Auto-generated on bed allocation in Room ${r.roomNumber}',
                    });
                  } catch (_) {}
                }

                notifier.fetchRoomDetail(r.id);
                notifier.fetchRooms();
                notifier.refreshAll();
              } else {
                final err = res['error'] ?? res['message'] ?? 'Failed to assign student';
                notifier.showError(err.toString());
              }
            }
          },
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Allocation'),
        ),
      ],
    );
  }
}
