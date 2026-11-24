import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AssignClassSectionDialog extends StatefulWidget {
  final BuildingModel building;
  final List<RoomModel> rooms;
  final BuildingOccupancyModel? preselectedRoom;
  final String? initialDate;
  final VoidCallback onSaved;

  const AssignClassSectionDialog({
    super.key,
    required this.building,
    required this.rooms,
    this.preselectedRoom,
    this.initialDate,
    required this.onSaved,
  });

  @override
  State<AssignClassSectionDialog> createState() => _AssignClassSectionDialogState();
}

class _AssignClassSectionDialogState extends State<AssignClassSectionDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedRoomId;
  RoomModel? _currentRoom;

  // Academic Entities
  bool _isLoadingEntities = true;
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _staffUsers = [];

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSection;
  String? _selectedSubject;
  String? _teacherName;
  final TextEditingController _teacherCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Schedule & Timing
  late DateTime _bookingDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  // Recurrence
  bool _isRecurring = false;
  String _recurrenceFreq = 'WEEKDAYS'; // 'DAILY', 'WEEKDAYS', 'WEEKLY'
  int _recurrenceCount = 5;

  bool _isSubmitting = false;
  String? _conflictError;

  @override
  void initState() {
    super.initState();

    // Initialize room
    if (widget.preselectedRoom != null) {
      _selectedRoomId = widget.preselectedRoom!.roomId;
      final match = widget.rooms.where((r) => r.id == _selectedRoomId);
      if (match.isNotEmpty) _currentRoom = match.first;
    } else if (widget.rooms.isNotEmpty) {
      _selectedRoomId = widget.rooms.first.id;
      _currentRoom = widget.rooms.first;
    }

    // Initialize date
    if (widget.initialDate != null) {
      try {
        _bookingDate = DateTime.parse(widget.initialDate!);
      } catch (_) {
        _bookingDate = DateTime.now();
      }
    } else {
      _bookingDate = DateTime.now();
    }

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingEntities = true);
    try {
      final results = await Future.wait([
        CampusApiService.instance.getAcademicEntitiesForAllocation(),
        CampusLookupHelper.instance.getStaffUsers(),
      ]);

      final entities = results[0] as Map<String, dynamic>;
      final staff = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(entities['classes'] ?? []);
          _subjects = List<Map<String, dynamic>>.from(entities['subjects'] ?? []);
          _staffUsers = staff;

          if (_classes.isNotEmpty) {
            _selectedClass = _classes.first;
            final sections = List<Map<String, dynamic>>.from(_selectedClass!['sections'] ?? []);
            if (sections.isNotEmpty) {
              _selectedSection = sections.first;
            }
          }
          if (_subjects.isNotEmpty) {
            _selectedSubject = _subjects.first['name']?.toString();
          }
          if (_staffUsers.isNotEmpty) {
            _teacherName = _staffUsers.first['name']?.toString() ?? 'Faculty Instructor';
            _teacherCtrl.text = _teacherName!;
          }
          _isLoadingEntities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingEntities = false);
    }
  }

  @override
  void dispose() {
    _teacherCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatDisplayTime(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _bookingDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto-advance end time by 1 hour if before or equal
        final startMins = picked.hour * 60 + picked.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          final newEndMins = (startMins + 60) % (24 * 60);
          _endTime = TimeOfDay(hour: newEndMins ~/ 60, minute: newEndMins % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      setState(() => _conflictError = 'Please select a room.');
      return;
    }
    if (_selectedClass == null || _selectedSection == null) {
      setState(() => _conflictError = 'Please select both class and section.');
      return;
    }

    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    if (startMins >= endMins) {
      setState(() => _conflictError = 'Start time must be strictly before end time.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _conflictError = null;
    });

    final payload = {
      'room_id': _selectedRoomId,
      'class_name': _selectedClass!['name']?.toString() ?? 'Class',
      'section_name': _selectedSection!['name']?.toString() ?? 'Section',
      'section_id': _selectedSection!['id']?.toString(),
      'subject': _selectedSubject ?? 'General Lecture',
      'teacher_name': _teacherCtrl.text.trim().isNotEmpty ? _teacherCtrl.text.trim() : 'Academic Faculty',
      'booking_date': DateFormat('yyyy-MM-dd').format(_bookingDate),
      'start_time': _formatTimeOfDay(_startTime),
      'end_time': _formatTimeOfDay(_endTime),
      'attendee_count': (_selectedSection!['capacity'] as num?)?.toInt() ?? 35,
      'is_recurring': _isRecurring,
      'recurrence_frequency': _recurrenceFreq,
      'recurrence_count': _recurrenceCount,
      'notes': _notesCtrl.text.trim(),
    };

    final res = await CampusApiService.instance.assignClassSectionToRoom(widget.building.id, payload);

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(res['message'] ?? 'Section successfully assigned to room via Space Booking!')),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _conflictError = res['message'] ?? res['detail'] ?? 'Failed to assign class/section to room.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomCap = _currentRoom?.maxCapacity ?? widget.preselectedRoom?.maxCapacity ?? 40;
    final sectionCap = (_selectedSection?['capacity'] as num?)?.toInt() ?? 40;
    final isCapacityFit = sectionCap <= roomCap;

    final sections = _selectedClass != null ? List<Map<String, dynamic>>.from(_selectedClass!['sections'] ?? []) : <Map<String, dynamic>>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: _isLoadingEntities
            ? const SizedBox(
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading academic classes, sections and timetable data...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Top Modal Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assign Class / Section to Space',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Allocate academic sessions via dynamic space booking schedule',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Form Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Conflict Alert Banner if any
                            if (_conflictError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _conflictError!,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 1. Room Selection Card
                            Text('1. TARGET PHYSICAL SPACE', style: _sectionHeaderStyle(isDark)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedRoomId,
                              decoration: _inputDecoration('Select Room / Hall', isDark, prefixIcon: Icons.meeting_room_outlined),
                              items: widget.rooms.map((r) {
                                return DropdownMenuItem(
                                  value: r.id,
                                  child: Text('${r.roomNumber} - ${r.name} (${r.roomType}, ${r.maxCapacity} seats)'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRoomId = val;
                                    final match = widget.rooms.where((r) => r.id == val);
                                    if (match.isNotEmpty) _currentRoom = match.first;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // 2. Class & Section Selection
                            Text('2. ACADEMIC CLASS & SECTION', style: _sectionHeaderStyle(isDark)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Class Dropdown
                                Expanded(
                                  child: DropdownButtonFormField<Map<String, dynamic>>(
                                    value: _selectedClass,
                                    decoration: _inputDecoration('Class / Grade', isDark, prefixIcon: Icons.class_outlined),
                                    items: _classes.map((c) {
                                      return DropdownMenuItem(
                                        value: c,
                                        child: Text(c['name']?.toString() ?? 'Class'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedClass = val;
                                          final secs = List<Map<String, dynamic>>.from(val['sections'] ?? []);
                                          _selectedSection = secs.isNotEmpty ? secs.first : null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Section Dropdown
                                Expanded(
                                  child: DropdownButtonFormField<Map<String, dynamic>>(
                                    value: _selectedSection,
                                    decoration: _inputDecoration('Section', isDark, prefixIcon: Icons.grid_view_rounded),
                                    items: sections.map((s) {
                                      final cap = s['capacity'] ?? 40;
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text('${s['name']} ($cap students)'),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedSection = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Capacity Fit Indicator Card
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCapacityFit ? const Color(0xFF059669).withValues(alpha: 0.08) : const Color(0xFFD97706).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCapacityFit ? const Color(0xFF059669).withValues(alpha: 0.25) : const Color(0xFFD97706).withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCapacityFit ? Icons.check_circle_outline : Icons.info_outline,
                                    size: 16,
                                    color: isCapacityFit ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isCapacityFit
                                          ? 'Capacity Match: Section capacity ($sectionCap) comfortably fits Room limit ($roomCap seats).'
                                          : 'Capacity Alert: Section capacity ($sectionCap) exceeds room limit ($roomCap seats).',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isCapacityFit ? const Color(0xFF059669) : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Subject & Faculty In-Charge
                            Text('3. CURRICULUM & FACULTY IN-CHARGE', style: _sectionHeaderStyle(isDark)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedSubject,
                                    decoration: _inputDecoration('Subject', isDark, prefixIcon: Icons.menu_book_rounded),
                                    items: _subjects.map((s) {
                                      final name = s['name']?.toString() ?? 'Subject';
                                      return DropdownMenuItem(value: name, child: Text(name));
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedSubject = val),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _teacherCtrl,
                                    decoration: _inputDecoration('Faculty In-Charge', isDark, prefixIcon: Icons.person_outline_rounded),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter faculty name' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 4. Date, Time Slot & Recurrence
                            Text('4. DATE & TIME ALLOCATION', style: _sectionHeaderStyle(isDark)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Date Picker Box
                                Expanded(
                                  flex: 5,
                                  child: InkWell(
                                    onTap: _pickDate,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: _inputDecoration('Date', isDark, prefixIcon: Icons.calendar_today_rounded),
                                      child: Text(
                                        DateFormat('EEE, dd MMM yyyy').format(_bookingDate),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Start Time
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: _pickStartTime,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: _inputDecoration('Start Time', isDark, prefixIcon: Icons.access_time_rounded),
                                      child: Text(
                                        _formatDisplayTime(_startTime),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // End Time
                                Expanded(
                                  flex: 4,
                                  child: InkWell(
                                    onTap: _pickEndTime,
                                    borderRadius: BorderRadius.circular(8),
                                    child: InputDecorator(
                                      decoration: _inputDecoration('End Time', isDark, prefixIcon: Icons.access_time_filled_rounded),
                                      child: Text(
                                        _formatDisplayTime(_endTime),
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Quick Time Preset Chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _timePresetChip('08:00 - 09:30 AM', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 9, minute: 30), isDark),
                                _timePresetChip('09:45 - 11:15 AM', const TimeOfDay(hour: 9, minute: 45), const TimeOfDay(hour: 11, minute: 15), isDark),
                                _timePresetChip('11:30 - 01:00 PM', const TimeOfDay(hour: 11, minute: 30), const TimeOfDay(hour: 13, minute: 0), isDark),
                                _timePresetChip('02:00 - 03:30 PM', const TimeOfDay(hour: 14, minute: 0), const TimeOfDay(hour: 15, minute: 30), isDark),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Recurrence Checkbox & Controls
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.repeat_rounded, size: 18, color: _isRecurring ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
                                          const SizedBox(width: 8),
                                          const Text('Repeat Schedule (Recurring Timetable)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                      Switch(
                                        value: _isRecurring,
                                        activeColor: const Color(0xFF4F46E5),
                                        onChanged: (val) => setState(() => _isRecurring = val),
                                      ),
                                    ],
                                  ),
                                  if (_isRecurring) ...[
                                    const Divider(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            value: _recurrenceFreq,
                                            decoration: _inputDecoration('Frequency', isDark),
                                            items: const [
                                              DropdownMenuItem(value: 'DAILY', child: Text('Every Day')),
                                              DropdownMenuItem(value: 'WEEKDAYS', child: Text('Mon - Fri (Weekdays)')),
                                              DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly (Same Day)')),
                                            ],
                                            onChanged: (val) => setState(() => _recurrenceFreq = val ?? 'WEEKDAYS'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            value: _recurrenceCount,
                                            decoration: _inputDecoration('Occurrences', isDark),
                                            items: const [
                                              DropdownMenuItem(value: 3, child: Text('3 Sessions')),
                                              DropdownMenuItem(value: 5, child: Text('5 Sessions (1 Week)')),
                                              DropdownMenuItem(value: 10, child: Text('10 Sessions (2 Weeks)')),
                                              DropdownMenuItem(value: 20, child: Text('20 Sessions (1 Month)')),
                                            ],
                                            onChanged: (val) => setState(() => _recurrenceCount = val ?? 5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Notes
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: _inputDecoration('Operational Notes (Optional)', isDark, prefixIcon: Icons.notes_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Action Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 12.5)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, size: 16),
                            label: Text(_isSubmitting ? 'Allocating...' : 'Confirm Allocation', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      ),
    );
  }

  Widget _timePresetChip(String label, TimeOfDay st, TimeOfDay et, bool isDark) {
    final isSelected = _startTime.hour == st.hour && _startTime.minute == st.minute && _endTime.hour == et.hour && _endTime.minute == et.minute;
    return InkWell(
      onTap: () => setState(() {
        _startTime = st;
        _endTime = et;
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  TextStyle _sectionHeaderStyle(bool isDark) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF4F46E5)) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      isDense: true,
    );
  }
}
