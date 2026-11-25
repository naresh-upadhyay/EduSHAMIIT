import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class CreateLeaveOutingDialog extends ConsumerStatefulWidget {
  final String initialType; // 'LEAVE' or 'OUTING'
  final String? initialStudentId;
  final String? initialStudentName;
  final String? initialStudentClass;
  final String? initialStudentHostel;
  final String? initialStudentRoom;
  final String? initialGuardianName;
  final String? initialGuardianPhone;

  const CreateLeaveOutingDialog({
    super.key,
    this.initialType = 'LEAVE',
    this.initialStudentId,
    this.initialStudentName,
    this.initialStudentClass,
    this.initialStudentHostel,
    this.initialStudentRoom,
    this.initialGuardianName,
    this.initialGuardianPhone,
  });

  @override
  ConsumerState<CreateLeaveOutingDialog> createState() => _CreateLeaveOutingDialogState();
}

class _CreateLeaveOutingDialogState extends ConsumerState<CreateLeaveOutingDialog> {
  int _currentStep = 0;

  // Form State
  String? _selectedStudentId;
  String _selectedStudentName = '';
  String _selectedStudentClass = '';
  String _selectedStudentHostel = '';
  String _selectedStudentRoom = '';
  String _guardianName = '';
  String _guardianPhone = '';

  late String _requestType;
  String _requestSubtype = 'Home Leave';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController();
  final TextEditingController _companionNameController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _startTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _returnTime = const TimeOfDay(hour: 18, minute: 0);

  bool _isEmergency = false;
  String _accompaniedBy = 'SELF';
  String _transportMode = 'WALK';
  bool _isSubmitting = false;

  static const List<String> _leaveSubtypes = [
    'Home Leave',
    'Medical',
    'Emergency',
    'Vacation',
    'Family Event',
    'Academic',
    'Personal',
    'Other',
  ];

  static const List<String> _outingSubtypes = [
    'Market',
    'Medical',
    'Coaching',
    'Shopping',
    'Bank',
    'Guardian Meeting',
    'Religious',
    'Personal',
    'Other',
  ];

  static const List<String> _transportModes = [
    'WALK',
    'AUTO',
    'CAB',
    'BUS',
    'TRAIN',
    'PERSONAL_VEHICLE',
    'INSTITUTION_VEHICLE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _requestType = widget.initialType;
    _requestSubtype = _requestType == 'LEAVE' ? 'Home Leave' : 'Market';
    if (widget.initialStudentId != null) {
      _selectedStudentId = widget.initialStudentId;
      _selectedStudentName = widget.initialStudentName ?? '';
      _selectedStudentClass = widget.initialStudentClass ?? '';
      _selectedStudentHostel = widget.initialStudentHostel ?? '';
      _selectedStudentRoom = widget.initialStudentRoom ?? '';
      _guardianName = widget.initialGuardianName ?? '';
      _guardianPhone = widget.initialGuardianPhone ?? '';
      _currentStep = 1;
    }
    _guardianNameController.text = _guardianName;
    _guardianPhoneController.text = _guardianPhone;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _destinationController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _companionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_task_rounded, size: 22, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New Movement Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Step ${_currentStep + 1} of 4: ${_getStepTitle(_currentStep)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              // Progress Bar
              LinearProgressIndicator(
                value: (_currentStep + 1) / 4,
                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),

              const SizedBox(height: 20),

              // Step Content Body
              Expanded(
                child: SingleChildScrollView(
                  child: _buildCurrentStepContent(isDark),
                ),
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Step Navigation Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      if (_currentStep < 3)
                        ElevatedButton(
                          onPressed: _validateAndProceed,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          child: const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          icon: _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                          label: const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Select Student';
      case 1:
        return 'Movement Type & Timing';
      case 2:
        return 'Details & Accompaniment';
      case 3:
        return 'Review & Submit';
      default:
        return '';
    }
  }

  void _validateAndProceed() {
    if (_currentStep == 1) {
      if (_reasonController.text.trim().isEmpty) {
        _showToast('Reason is required');
        return;
      }
      if (_destinationController.text.trim().isEmpty) {
        _showToast('Destination is required');
        return;
      }
    }
    setState(() => _currentStep++);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  Future<void> _submitRequest() async {
    setState(() => _isSubmitting = true);

    final startAt = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final returnAt = DateTime(
      _returnDate.year,
      _returnDate.month,
      _returnDate.day,
      _returnTime.hour,
      _returnTime.minute,
    );

    final payload = {
      'student_id': _selectedStudentId,
      'academic_year': ref.read(hostelProvider).selectedAcademicYear,
      'request_type': _requestType,
      'request_subtype': _requestSubtype,
      'reason': _reasonController.text.trim(),
      'destination': _destinationController.text.trim(),
      'start_at': startAt.toIso8601String(),
      'expected_return_at': returnAt.toIso8601String(),
      'is_emergency': _isEmergency,
      'accompanied_by': _accompaniedBy,
      'companion_name': _companionNameController.text.trim().isEmpty ? null : _companionNameController.text.trim(),
      'transport_mode': _transportMode,
      'guardian_name': _guardianNameController.text.trim(),
      'guardian_phone': _guardianPhoneController.text.trim(),
    };

    final ok = await ref.read(hostelProvider.notifier).createLeaveOutingRequest(payload);
    setState(() => _isSubmitting = false);

    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildCurrentStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Student(isDark);
      case 1:
        return _buildStep2Movement(isDark);
      case 2:
        return _buildStep3Guardian(isDark);
      case 3:
        return _buildStep4Review(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1Student(bool isDark) {
    final roster = ref.watch(hostelProvider).studentsRoster;
    final students = roster.isNotEmpty
        ? roster.map((s) => {
            'id': s.studentId,
            'name': s.studentName,
            'class': s.className,
            'hostel': s.hostelName,
            'room': s.roomNumber,
            'guardian': s.guardianName.isNotEmpty ? s.guardianName : 'Guardian',
            'phone': s.emergencyContact.isNotEmpty ? s.emergencyContact : 'N/A',
          }).toList()
        : [
            {
              'id': 'a1000001-0000-0000-0000-000000000001',
              'name': 'Active Resident',
              'class': 'Hostel Wing',
              'hostel': 'Hostel Block',
              'room': '101',
              'guardian': 'Guardian',
              'phone': 'N/A',
            },
          ];

    if (_selectedStudentId == null && students.isNotEmpty) {
      _selectedStudentId = students.first['id'];
      _selectedStudentName = students.first['name'] ?? '';
      _selectedStudentClass = students.first['class'] ?? '';
      _selectedStudentHostel = students.first['hostel'] ?? '';
      _selectedStudentRoom = students.first['room'] ?? '';
      _guardianName = students.first['guardian'] ?? '';
      _guardianPhone = students.first['phone'] ?? '';
      _guardianNameController.text = _guardianName;
      _guardianPhoneController.text = _guardianPhone;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Hostel Student',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose an actively allocated hostel student to auto-populate room and guardian records.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        ...students.map((st) {
          final isSelected = _selectedStudentId == st['id'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFDBEAFE),
                child: Text(
                  st['name']![0],
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
              title: Text(
                st['name']!,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              subtitle: Text(
                '${st['class']} • ${st['hostel']} (Room ${st['room']})',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
              onTap: () {
                setState(() {
                  _selectedStudentId = st['id'];
                  _selectedStudentName = st['name']!;
                  _selectedStudentClass = st['class']!;
                  _selectedStudentHostel = st['hostel']!;
                  _selectedStudentRoom = st['room']!;
                  _guardianName = st['guardian']!;
                  _guardianPhone = st['phone']!;
                  _guardianNameController.text = _guardianName;
                  _guardianPhoneController.text = _guardianPhone;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2Movement(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movement Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard('LEAVE', 'Leave', 'Multi-day absence from hostel', Icons.flight_takeoff_rounded, isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeCard('OUTING', 'Outing', 'Short daytime outing from hostel', Icons.directions_walk_rounded, isDark),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Text(
          'Sub-Type',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _requestSubtype,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          items: (_requestType == 'LEAVE' ? _leaveSubtypes : _outingSubtypes).map((s) {
            return DropdownMenuItem(value: s, child: Text(s));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _requestSubtype = v);
          },
        ),

        const SizedBox(height: 14),
        Text(
          'Destination *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _destinationController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'e.g. Hometown (Jaipur) or City Market',
            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'Reason *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _reasonController,
          maxLines: 2,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Specify movement purpose in detail...',
            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),

        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Departure Date & Time *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _startDate = pickedDate;
                            _startTime = pickedTime;
                            if (_returnDate.isBefore(_startDate)) {
                              _returnDate = _startDate.add(const Duration(hours: 4));
                            }
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(
                            '${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year} ${_startTime.format(context)}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ],
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
                  Text(
                    'Expected Return *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _returnDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _returnTime,
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _returnDate = pickedDate;
                            _returnTime = pickedTime;
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Text(
                            '${_returnDate.day.toString().padLeft(2, '0')}/${_returnDate.month.toString().padLeft(2, '0')}/${_returnDate.year} ${_returnTime.format(context)}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Emergency Request',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            'Flags as high priority in warden approval queue',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          value: _isEmergency,
          onChanged: (v) => setState(() => _isEmergency = v),
          activeThumbColor: const Color(0xFFDC2626),
        ),
      ],
    );
  }

  Widget _buildTypeCard(String type, String title, String sub, IconData icon, bool isDark) {
    final isSelected = _requestType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _requestType = type;
          _requestSubtype = type == 'LEAVE' ? 'Home Leave' : 'Market';
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

  Widget _buildStep3Guardian(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guardian Contact Snapshot',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _guardianNameController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Guardian Name',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _guardianPhoneController,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Guardian Phone',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),

        const SizedBox(height: 18),
        Text(
          'Accompaniment & Travel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _accompaniedBy,
          decoration: InputDecoration(
            labelText: 'Accompanied By',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          items: const ['SELF', 'PARENT', 'GUARDIAN', 'AUTHORIZED_PERSON', 'STAFF', 'GROUP'].map((a) {
            return DropdownMenuItem(value: a, child: Text(a));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _accompaniedBy = v);
          },
        ),

        if (_accompaniedBy != 'SELF') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _companionNameController,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Companion Name / Relation',
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _transportMode,
          decoration: InputDecoration(
            labelText: 'Transport Mode',
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          items: _transportModes.map((t) {
            return DropdownMenuItem(value: t, child: Text(t));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _transportMode = v);
          },
        ),
      ],
    );
  }

  Widget _buildStep4Review(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Summary of Movement Request',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildReviewRow('Student', '$_selectedStudentName ($_selectedStudentClass)', isDark),
          _buildReviewRow('Hostel / Room', '$_selectedStudentHostel (Room $_selectedStudentRoom)', isDark),
          _buildReviewRow('Type', '$_requestType • $_requestSubtype', isDark),
          _buildReviewRow('Reason', _reasonController.text.trim(), isDark),
          _buildReviewRow('Destination', _destinationController.text.trim(), isDark),
          _buildReviewRow('Accompanied By', _accompaniedBy, isDark),
          _buildReviewRow('Transport', _transportMode, isDark),
          _buildReviewRow('Guardian', '${_guardianNameController.text} (${_guardianPhoneController.text})', isDark),
          if (_isEmergency) _buildReviewRow('Priority', 'EMERGENCY LEAVE', isDark),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
