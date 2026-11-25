import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/space_booking_provider.dart';

class RecurringBookingDialog extends ConsumerStatefulWidget {
  const RecurringBookingDialog({super.key});

  @override
  ConsumerState<RecurringBookingDialog> createState() => _RecurringBookingDialogState();
}

class _RecurringBookingDialogState extends ConsumerState<RecurringBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _seriesTitleCtrl = TextEditingController(text: 'Weekly Science Lab Demonstrations');

  String _recurrenceType = 'WEEKLY';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 90));
  final Set<int> _selectedDays = {1, 3, 5}; // Mon, Wed, Fri
  String? _selectedRoomId;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  String _conflictStrategy = 'Skip Conflicts';

  @override
  void dispose() {
    _seriesTitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(620.0, screenWidth * 0.95);

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    if (_selectedRoomId == null && state.bookableRooms.isNotEmpty) {
      _selectedRoomId = state.bookableRooms.first.id;
    }

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dialogBorder),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Recurring Space Booking',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Generate recurring slots for classes, labs, faculty seminars, or club activities',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(color: dialogBorder, height: 24),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 500;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Series Title
                          _buildLabel('Series Title *', textSecondary),
                          TextFormField(
                            controller: _seriesTitleCtrl,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: _inputDeco('e.g. Weekly CS Practical Lab 1', isDark, inputBg, inputBorder),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Room Selection
                          _buildLabel('Space / Room *', textSecondary),
                          AppSearchableDropdownFormField<String>.fromMenuItems(
                            initialValue: state.bookableRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
                            isExpanded: true,
                            dropdownColor: dialogBg,
                            style: TextStyle(fontSize: 13, color: textPrimary),
                            decoration: _inputDeco('Select Room', isDark, inputBg, inputBorder),
                            items: state.bookableRooms.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                child: Text('${r.name} (${r.roomType}) • ${r.buildingName}', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => _selectedRoomId = v),
                            validator: (v) => v == null ? 'Room required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Recurrence Pattern & Strategy
                          if (isCompact) ...[
                            _buildLabel('Recurrence Pattern *', textSecondary),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _recurrenceType,
                              isExpanded: true,
                              dropdownColor: dialogBg,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _inputDeco('', isDark, inputBg, inputBorder),
                              items: const [
                                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                                DropdownMenuItem(value: 'DAILY', child: Text('Daily (Every Day)')),
                                DropdownMenuItem(value: 'WEEKDAYS', child: Text('Weekdays (Mon - Fri)')),
                                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                                DropdownMenuItem(value: 'SEMESTER', child: Text('Full Semester')),
                              ],
                              onChanged: (v) => setState(() => _recurrenceType = v ?? 'WEEKLY'),
                            ),
                            const SizedBox(height: 12),
                            _buildLabel('Conflict Handling Strategy', textSecondary),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _conflictStrategy,
                              isExpanded: true,
                              dropdownColor: dialogBg,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _inputDeco('', isDark, inputBg, inputBorder),
                              items: const [
                                DropdownMenuItem(value: 'Skip Conflicts', child: Text('Skip Conflicts')),
                                DropdownMenuItem(value: 'Halt on Conflict', child: Text('Halt on Conflict')),
                                DropdownMenuItem(value: 'Force Overwrite', child: Text('Notify Administrator')),
                              ],
                              onChanged: (v) => setState(() => _conflictStrategy = v ?? 'Skip Conflicts'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Recurrence Pattern *', textSecondary),
                                      AppSearchableDropdownFormField<String>.fromMenuItems(
                                        initialValue: _recurrenceType,
                                        isExpanded: true,
                                        dropdownColor: dialogBg,
                                        style: TextStyle(fontSize: 13, color: textPrimary),
                                        decoration: _inputDeco('', isDark, inputBg, inputBorder),
                                        items: const [
                                          DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                                          DropdownMenuItem(value: 'DAILY', child: Text('Daily (Every Day)')),
                                          DropdownMenuItem(value: 'WEEKDAYS', child: Text('Weekdays (Mon - Fri)')),
                                          DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                                          DropdownMenuItem(value: 'SEMESTER', child: Text('Full Semester')),
                                        ],
                                        onChanged: (v) => setState(() => _recurrenceType = v ?? 'WEEKLY'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Conflict Handling Strategy', textSecondary),
                                      AppSearchableDropdownFormField<String>.fromMenuItems(
                                        initialValue: _conflictStrategy,
                                        isExpanded: true,
                                        dropdownColor: dialogBg,
                                        style: TextStyle(fontSize: 13, color: textPrimary),
                                        decoration: _inputDeco('', isDark, inputBg, inputBorder),
                                        items: const [
                                          DropdownMenuItem(value: 'Skip Conflicts', child: Text('Skip Conflicts')),
                                          DropdownMenuItem(value: 'Halt on Conflict', child: Text('Halt on Conflict')),
                                          DropdownMenuItem(value: 'Force Overwrite', child: Text('Notify Administrator')),
                                        ],
                                        onChanged: (v) => setState(() => _conflictStrategy = v ?? 'Skip Conflicts'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),

                          // Day Selector
                          if (_recurrenceType == 'WEEKLY') ...[
                            _buildLabel('Repeat on Days of Week *', textSecondary),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildDayCircle(1, 'M', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(2, 'T', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(3, 'W', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(4, 'T', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(5, 'F', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(6, 'S', isDark),
                                  const SizedBox(width: 8),
                                  _buildDayCircle(7, 'S', isDark),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Date Range
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Start Date *', textSecondary),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _startDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2030),
                                        );
                                        if (d != null) setState(() => _startDate = d);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          border: Border.all(color: inputBorder),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            Text('${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                                style: TextStyle(fontSize: 13, color: textPrimary)),
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
                                    _buildLabel('End Date *', textSecondary),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _endDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2030),
                                        );
                                        if (d != null) setState(() => _endDate = d);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          border: Border.all(color: inputBorder),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 16, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            Text('${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                                style: TextStyle(fontSize: 13, color: textPrimary)),
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

                          // Time Range
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Start Time *', textSecondary),
                                    InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _startTime);
                                        if (t != null) setState(() => _startTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          border: Border.all(color: inputBorder),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            Text(_startTime.format(context), style: TextStyle(fontSize: 13, color: textPrimary)),
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
                                    _buildLabel('End Time *', textSecondary),
                                    InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _endTime);
                                        if (t != null) setState(() => _endTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          border: Border.all(color: inputBorder),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            Text(_endTime.format(context), style: TextStyle(fontSize: 13, color: textPrimary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              Divider(color: dialogBorder, height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState?.validate() != true) return;
                      if (_selectedRoomId == null) return;

                      final startFormatted = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
                      final endFormatted = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

                      final payload = {
                        'title': _seriesTitleCtrl.text.trim(),
                        'room_id': _selectedRoomId,
                        'start_date': '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                        'end_date': '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                        'days_of_week': _selectedDays.toList(),
                        'start_time': startFormatted,
                        'end_time': endFormatted,
                        'purpose': 'Academic',
                        'organizer_name': 'Academic Coordinator',
                        'organizer_role': 'Faculty',
                        'attendee_count': 35,
                      };

                      final nav = Navigator.of(context);
                      final scf = ScaffoldMessenger.of(context);
                      final res = await notifier.submitRecurringBooking(payload);
                      if (!mounted) return;
                      if (res['success'] == true) {
                        nav.pop();
                        final msg = res['data']?['message'] ?? 'Recurring space booking series established successfully!';
                        scf.showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      } else {
                        scf.showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Failed to generate recurring series.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Generate Recurring Series', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _buildDayCircle(int dayNum, String letter, bool isDark) {
    final isSel = _selectedDays.contains(dayNum);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSel) {
            _selectedDays.remove(dayNum);
          } else {
            _selectedDays.add(dayNum);
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          shape: BoxShape.circle,
          border: Border.all(color: isSel ? const Color(0xFF1D4ED8) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, bool isDark, Color inputBg, Color inputBorder) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }
}
