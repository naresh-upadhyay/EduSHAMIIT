import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/space_booking_models.dart';
import '../../../providers/space_booking_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class CreateEditBookingDialog extends ConsumerStatefulWidget {
  final SpaceBookingRequestItem? initialItem;

  const CreateEditBookingDialog({
    super.key,
    this.initialItem,
  });

  @override
  ConsumerState<CreateEditBookingDialog> createState() => _CreateEditBookingDialogState();
}

class _CreateEditBookingDialogState extends ConsumerState<CreateEditBookingDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _organizerNameCtrl;
  late TextEditingController _organizerEmailCtrl;
  late TextEditingController _organizerPhoneCtrl;
  late TextEditingController _attendeesCtrl;
  late TextEditingController _specialInstructionsCtrl;

  String _purpose = 'Academic';
  String _category = 'Academic';
  String _priority = 'Normal';
  String _organizerRole = 'Faculty';
  String? _selectedRoomId;
  DateTime _bookingDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 16, minute: 0);
  int _setupMinutes = 10;
  int _cleanupMinutes = 10;
  bool _projector = false;
  bool _audioMic = false;
  bool _whiteboard = false;
  bool _videoConferencing = false;

  List<String> _bookingPurposes = [];
  List<String> _organizerRoles = [];

  @override
  void initState() {
    super.initState();
    _bookingPurposes = CampusLookupHelper.instance.getImmediateLabels('BOOKING_PURPOSE');
    _organizerRoles = [
      'Faculty',
      'Student Club / Representative',
      'Department HOD',
      'Administration Office',
      'IT & Network Team',
      'Cultural Committee',
      'Sports & Athletics Staff',
    ];
    _loadLookups();

    final item = widget.initialItem;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _descCtrl = TextEditingController(text: item?.description ?? '');
    _organizerNameCtrl = TextEditingController(text: item?.organizerName ?? '');
    _organizerEmailCtrl = TextEditingController(text: '');
    _organizerPhoneCtrl = TextEditingController(text: '');
    _attendeesCtrl = TextEditingController(text: item != null ? '${item.attendeeCount}' : '30');
    _specialInstructionsCtrl = TextEditingController(text: '');

    if (item != null) {
      _purpose = item.purpose;
      _category = item.category;
      _priority = item.priority;
      _organizerRole = item.organizerRole;
      _selectedRoomId = item.roomId;
    }
  }

  Future<void> _loadLookups() async {
    final purposes = await CampusLookupHelper.instance.getLookupLabels('BOOKING_PURPOSE');
    final roles = await CampusLookupHelper.instance.getLookupLabels('ORGANIZER_ROLE');
    if (mounted) {
      setState(() {
        if (purposes.isNotEmpty) {
          _bookingPurposes = purposes;
          if (!_bookingPurposes.contains(_purpose) && _bookingPurposes.isNotEmpty) {
            _purpose = _bookingPurposes.first;
          }
        }
        if (roles.isNotEmpty) {
          _organizerRoles = roles;
          if (!_organizerRoles.contains(_organizerRole) && _organizerRoles.isNotEmpty) {
            _organizerRole = _organizerRoles.first;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _organizerNameCtrl.dispose();
    _organizerEmailCtrl.dispose();
    _organizerPhoneCtrl.dispose();
    _attendeesCtrl.dispose();
    _specialInstructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(680.0, screenWidth * 0.95);

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final inputBorder = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final primaryColor = Theme.of(context).colorScheme.primary;

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
              // Dialog Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.meeting_room, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialItem == null ? 'Book a Campus Space' : 'Edit Space Booking',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Configure room selection, timings, setup buffer, and equipment requests',
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

              // Scrollable Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 520;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Space & Schedule
                          _buildSectionTitle('1. Space & Schedule', textPrimary),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            _buildFormField(
                              label: 'Booking Title *',
                              color: textSecondary,
                              child: TextFormField(
                                controller: _titleCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('Enter booking title', isDark, inputBg, inputBorder),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              label: 'Purpose *',
                              color: textSecondary,
                              child: DropdownButtonFormField<String>(
                                initialValue: _purpose,
                                isExpanded: true,
                                dropdownColor: dialogBg,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                items: _bookingPurposes
                                    .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) => setState(() => _purpose = v ?? 'Academic'),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormField(
                                    label: 'Booking Title *',
                                    color: textSecondary,
                                    child: TextFormField(
                                      controller: _titleCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('Enter booking title', isDark, inputBg, inputBorder),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildFormField(
                                    label: 'Purpose *',
                                    color: textSecondary,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _purpose,
                                      isExpanded: true,
                                      dropdownColor: dialogBg,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                      items: _bookingPurposes
                                          .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _purpose = v ?? 'Academic'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Room Dropdown
                          _buildFormField(
                            label: 'Select Space / Room *',
                            color: textSecondary,
                            child: DropdownButtonFormField<String>(
                              initialValue: state.bookableRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
                              isExpanded: true,
                              dropdownColor: dialogBg,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _inputDecoration('Select Bookable Room', isDark, inputBg, inputBorder),
                              items: state.bookableRooms.map((r) {
                                return DropdownMenuItem(
                                  value: r.id,
                                  child: Text(
                                    '${r.name} (${r.roomType}) • ${r.buildingName} • Capacity: ${r.maxCapacity}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedRoomId = v),
                              validator: (v) => v == null ? 'Room required' : null,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Date, Start Time, End Time
                          if (isCompact) ...[
                            _buildFormField(
                              label: 'Date *',
                              color: textSecondary,
                              child: InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _bookingDate,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (d != null) setState(() => _bookingDate = d);
                                },
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    border: Border.all(color: inputBorder),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, size: 16, color: Color(0xFF3B82F6)),
                                      const SizedBox(width: 8),
                                      Text('${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year}',
                                          style: TextStyle(fontSize: 13, color: textPrimary)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Start Time *',
                                    color: textSecondary,
                                    child: InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _startTime);
                                        if (t != null) setState(() => _startTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'End Time *',
                                    color: textSecondary,
                                    child: InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _endTime);
                                        if (t != null) setState(() => _endTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Date *',
                                    color: textSecondary,
                                    child: InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(
                                          context: context,
                                          initialDate: _bookingDate,
                                          firstDate: DateTime(2025),
                                          lastDate: DateTime(2030),
                                        );
                                        if (d != null) setState(() => _bookingDate = d);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          border: Border.all(color: inputBorder),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF3B82F6)),
                                            const SizedBox(width: 8),
                                            Text('${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year}',
                                                style: TextStyle(fontSize: 13, color: textPrimary)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Start Time *',
                                    color: textSecondary,
                                    child: InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _startTime);
                                        if (t != null) setState(() => _startTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'End Time *',
                                    color: textSecondary,
                                    child: InkWell(
                                      onTap: () async {
                                        final t = await showTimePicker(context: context, initialTime: _endTime);
                                        if (t != null) setState(() => _endTime = t);
                                      },
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),

                          // Buffer Times & Attendees
                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Setup Buffer',
                                  color: textSecondary,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _setupMinutes,
                                    isExpanded: true,
                                    dropdownColor: dialogBg,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('0 mins')),
                                      DropdownMenuItem(value: 10, child: Text('10 mins')),
                                      DropdownMenuItem(value: 15, child: Text('15 mins')),
                                      DropdownMenuItem(value: 30, child: Text('30 mins')),
                                    ],
                                    onChanged: (v) => setState(() => _setupMinutes = v ?? 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Cleanup Buffer',
                                  color: textSecondary,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _cleanupMinutes,
                                    isExpanded: true,
                                    dropdownColor: dialogBg,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                    items: const [
                                      DropdownMenuItem(value: 0, child: Text('0 mins')),
                                      DropdownMenuItem(value: 10, child: Text('10 mins')),
                                      DropdownMenuItem(value: 15, child: Text('15 mins')),
                                      DropdownMenuItem(value: 30, child: Text('30 mins')),
                                    ],
                                    onChanged: (v) => setState(() => _cleanupMinutes = v ?? 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Attendees',
                                  color: textSecondary,
                                  child: TextFormField(
                                    controller: _attendeesCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                    decoration: _inputDecoration('e.g. 40', isDark, inputBg, inputBorder),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Section 2: Requester Details
                          _buildSectionTitle('2. Requester & Contact', textPrimary),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            _buildFormField(
                              label: 'Organizer Name *',
                              color: textSecondary,
                              child: TextFormField(
                                controller: _organizerNameCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('Full Name', isDark, inputBg, inputBorder),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              label: 'Organizer Role',
                              color: textSecondary,
                              child: DropdownButtonFormField<String>(
                                initialValue: _organizerRoles.contains(_organizerRole) ? _organizerRole : (_organizerRoles.isNotEmpty ? _organizerRoles.first : null),
                                isExpanded: true,
                                dropdownColor: dialogBg,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                items: _organizerRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                onChanged: (v) => setState(() => _organizerRole = v ?? (_organizerRoles.isNotEmpty ? _organizerRoles.first : 'Faculty')),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              label: 'Email',
                              color: textSecondary,
                              child: TextFormField(
                                controller: _organizerEmailCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('Email Address', isDark, inputBg, inputBorder),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildFormField(
                              label: 'Phone',
                              color: textSecondary,
                              child: TextFormField(
                                controller: _organizerPhoneCtrl,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: _inputDecoration('+91 Phone Number', isDark, inputBg, inputBorder),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Organizer Name *',
                                    color: textSecondary,
                                    child: TextFormField(
                                      controller: _organizerNameCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('Full Name', isDark, inputBg, inputBorder),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Organizer Role',
                                    color: textSecondary,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _organizerRoles.contains(_organizerRole) ? _organizerRole : (_organizerRoles.isNotEmpty ? _organizerRoles.first : null),
                                      isExpanded: true,
                                      dropdownColor: dialogBg,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                                      items: _organizerRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                      onChanged: (v) => setState(() => _organizerRole = v ?? (_organizerRoles.isNotEmpty ? _organizerRoles.first : 'Faculty')),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Email',
                                    color: textSecondary,
                                    child: TextFormField(
                                      controller: _organizerEmailCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('Email Address', isDark, inputBg, inputBorder),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildFormField(
                                    label: 'Phone',
                                    color: textSecondary,
                                    child: TextFormField(
                                      controller: _organizerPhoneCtrl,
                                      style: TextStyle(fontSize: 13, color: textPrimary),
                                      decoration: _inputDecoration('+91 Phone Number', isDark, inputBg, inputBorder),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Section 3: Amenities & Instructions
                          _buildSectionTitle('3. Required Amenities & Equipment', textPrimary),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildAmenityChip('Projector & Screen', _projector, isDark, (v) => setState(() => _projector = v)),
                              _buildAmenityChip('Audio System / Microphones', _audioMic, isDark, (v) => setState(() => _audioMic = v)),
                              _buildAmenityChip('Whiteboard & Markers', _whiteboard, isDark, (v) => setState(() => _whiteboard = v)),
                              _buildAmenityChip('Video Conferencing Setup', _videoConferencing, isDark, (v) => setState(() => _videoConferencing = v)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          _buildFormField(
                            label: 'Special Instructions',
                            color: textSecondary,
                            child: TextFormField(
                              controller: _specialInstructionsCtrl,
                              maxLines: 2,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: _inputDecoration('Any layout, security or catering notes...', isDark, inputBg, inputBorder),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              Divider(color: dialogBorder, height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            if (_formKey.currentState?.validate() != true) return;
                            if (_selectedRoomId == null) return;

                            final startFormatted = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
                            final endFormatted = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

                            final payload = {
                              'id': widget.initialItem?.id,
                              'title': _titleCtrl.text.trim(),
                              'description': _descCtrl.text.trim(),
                              'purpose': _purpose,
                              'category': _category,
                              'priority': _priority,
                              'room_id': _selectedRoomId,
                              'booking_date': '${_bookingDate.year}-${_bookingDate.month.toString().padLeft(2, '0')}-${_bookingDate.day.toString().padLeft(2, '0')}',
                              'start_time': startFormatted,
                              'end_time': endFormatted,
                              'setup_minutes': _setupMinutes,
                              'cleanup_minutes': _cleanupMinutes,
                              'organizer_name': _organizerNameCtrl.text.trim(),
                              'organizer_role': _organizerRole,
                              'organizer_email': _organizerEmailCtrl.text.trim(),
                              'organizer_phone': _organizerPhoneCtrl.text.trim(),
                              'attendee_count': int.tryParse(_attendeesCtrl.text.trim()) ?? 1,
                              'special_instructions': _specialInstructionsCtrl.text.trim(),
                              'amenities_required': [
                                if (_projector) 'Projector',
                                if (_audioMic) 'Audio System',
                                if (_whiteboard) 'Whiteboard',
                                if (_videoConferencing) 'Video Conferencing',
                              ],
                            };

                            final ok = await notifier.submitBooking(payload);
                            if (ok && mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Space booking saved successfully!')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      widget.initialItem == null ? 'Submit Request' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
    );
  }

  Widget _buildFormField({required String label, required Color color, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildAmenityChip(String label, bool isSelected, bool isDark, ValueChanged<bool> onChanged) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? (isDark ? Colors.white : primaryColor) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
        ),
      ),
      selected: isSelected,
      onSelected: onChanged,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      selectedColor: isDark ? primaryColor.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.12),
      checkmarkColor: isDark ? Colors.white : primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: isSelected ? primaryColor : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark, Color inputBg, Color inputBorder) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryColor, width: 1.5)),
    );
  }
}
