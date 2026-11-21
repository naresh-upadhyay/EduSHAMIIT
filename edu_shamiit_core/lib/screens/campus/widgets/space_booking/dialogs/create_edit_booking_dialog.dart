import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/space_booking_models.dart';
import '../../../providers/space_booking_provider.dart';
import '../../../services/campus_lookup_helper.dart';
import '../../../services/space_booking_api_service.dart';
import 'space_conflict_warning_dialog.dart';

class CreateEditBookingDialog extends ConsumerStatefulWidget {
  final SpaceBookingRequestItem? initialItem;
  final String? preselectedRoomId;

  const CreateEditBookingDialog({
    super.key,
    this.initialItem,
    this.preselectedRoomId,
  });

  @override
  ConsumerState<CreateEditBookingDialog> createState() => _CreateEditBookingDialogState();
}

class _CreateEditBookingDialogState extends ConsumerState<CreateEditBookingDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  int _currentTabIndex = 0;

  // Controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _organizerNameCtrl;
  late TextEditingController _organizerEmailCtrl;
  late TextEditingController _organizerPhoneCtrl;
  late TextEditingController _attendeesCtrl;
  late TextEditingController _specialInstructionsCtrl;
  late TextEditingController _requesterSearchCtrl;

  // Space & Schedule State
  String _purpose = 'Academic';
  String _category = 'Academic';
  String _priority = 'Normal';
  String _organizerRole = 'Faculty';
  String? _selectedRoomId;
  DateTime _bookingDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  int _setupMinutes = 10;
  int _cleanupMinutes = 10;

  // Recurrence State (10x Architect Grade from Calendar Screen)
  String _recurrenceFreq = 'none'; // 'none', 'daily', 'weekdays', 'weekly', 'monthly', 'yearly', 'custom'
  int _recurrenceInterval = 1;
  List<String> _recurrenceDays = ['MO', 'WE', 'FR'];
  String _recurrenceEndType = 'never'; // 'never', 'count', 'date'
  int _recurrenceCount = 10;
  DateTime _recurrenceUntilDate = DateTime.now().add(const Duration(days: 60));

  // Real-time Free / Busy & Conflict Detection State
  bool _isCheckingSlot = false;
  bool _hasSlotConflict = false;
  String? _slotConflictMessage;

  // Dynamic Requester State (from User Management)
  List<SpaceRequesterProfile> _requesters = [];
  bool _isLoadingRequesters = false;
  SpaceRequesterProfile? _selectedRequester;
  String? _requesterUserId;
  bool _showRequesterDropdown = false;

  // Amenities State
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
    if (_bookingPurposes.isEmpty) {
      _bookingPurposes = [
        'Academic',
        'Workshop',
        'Exam',
        'Club Activity',
        'Faculty Meeting',
        'Cultural Event',
        'Sports Event',
      ];
    }
    if (!_bookingPurposes.contains(_purpose)) {
      _bookingPurposes.insert(0, _purpose);
    }
    _organizerRoles = [
      'Faculty',
      'Student Club / Representative',
      'Department HOD',
      'Administration Office',
      'IT & Network Team',
      'Cultural Committee',
      'Sports & Athletics Staff',
    ];
    if (!_organizerRoles.contains(_organizerRole)) {
      _organizerRoles.insert(0, _organizerRole);
    }
    _loadLookups();

    final item = widget.initialItem;
    _titleCtrl = TextEditingController(text: item?.title ?? '');
    _descCtrl = TextEditingController(text: item?.description ?? '');
    _organizerNameCtrl = TextEditingController(text: item?.organizerName ?? '');
    _organizerEmailCtrl = TextEditingController(text: '');
    _organizerPhoneCtrl = TextEditingController(text: '');
    _attendeesCtrl = TextEditingController(text: item != null ? '${item.attendeeCount}' : '30');
    _specialInstructionsCtrl = TextEditingController(text: '');
    _requesterSearchCtrl = TextEditingController(text: item != null ? (item.organizerName.isNotEmpty ? item.organizerName : item.requestedByDisplay) : '');

    if (item != null) {
      _purpose = item.purpose;
      _category = item.category;
      _priority = item.priority;
      _organizerRole = item.organizerRole;
      _selectedRoomId = item.roomId.isNotEmpty ? item.roomId : null;

      final parsedDate = _parseDate(item.bookingDate);
      if (parsedDate != null) _bookingDate = parsedDate;

      final parsedStart = _parseTime(item.startTime);
      if (parsedStart != null) _startTime = parsedStart;

      final parsedEnd = _parseTime(item.endTime);
      if (parsedEnd != null) _endTime = parsedEnd;

      if (item.isRecurring) {
        _recurrenceFreq = 'daily';
      }

      if (item.id.isNotEmpty) {
        _loadInitialDetails(item.id);
      }
    } else {
      if (widget.preselectedRoomId != null && widget.preselectedRoomId!.isNotEmpty) {
        _selectedRoomId = widget.preselectedRoomId;
      }
      try {
        final currentCalDate = ref.read(spaceBookingProvider).selectedDate;
        _bookingDate = currentCalDate;
      } catch (_) {}
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 9, minute: 0);
    }

    _fetchRequesters('');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.initialItem == null) {
          final calDate = ref.read(spaceBookingProvider).selectedDate;
          if (_bookingDate != calDate) {
            setState(() {
              _bookingDate = calDate;
            });
          }
        }
        if (_selectedRoomId == null && ref.read(spaceBookingProvider).bookableRooms.isNotEmpty) {
          setState(() {
            _selectedRoomId = ref.read(spaceBookingProvider).bookableRooms.first.id;
          });
        }
        _checkLiveSlotStatus();
      }
    });
  }

  int _timeOfDayToMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

  int _timeStrToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final timePart = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timePart.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return hour * 60 + minute;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _checkLiveSlotStatus() async {
    final roomId = _selectedRoomId;
    if (roomId == null || roomId.isEmpty) return;

    final startMinutes = _timeOfDayToMinutes(_startTime) - _setupMinutes;
    final endMinutes = _timeOfDayToMinutes(_endTime) + _cleanupMinutes;

    // 1. Instant local timeline evaluation from loaded rooms if viewing selected date
    final state = ref.read(spaceBookingProvider);
    final roomInTimeline = state.roomsTimeline.cast<SpaceTimelineRoom?>().firstWhere(
      (r) => r?.roomId == roomId,
      orElse: () => null,
    );

    bool localConflictFound = false;
    String? localTitle;
    String? localSched;

    final isSameDate = _bookingDate.year == state.selectedDate.year &&
        _bookingDate.month == state.selectedDate.month &&
        _bookingDate.day == state.selectedDate.day;

    if (roomInTimeline != null && isSameDate) {
      for (final b in roomInTimeline.bookings) {
        if (widget.initialItem != null && b.id == widget.initialItem!.id) continue;
        final bStart = _timeStrToMinutes(b.startTime);
        final bEnd = _timeStrToMinutes(b.endTime);
        if (startMinutes < bEnd && endMinutes > bStart) {
          localConflictFound = true;
          localTitle = b.title;
          localSched = '${b.startTime} - ${b.endTime}';
          break;
        }
      }
      if (mounted) {
        setState(() {
          _isCheckingSlot = false;
          _hasSlotConflict = localConflictFound;
          if (localConflictFound) {
            _slotConflictMessage = 'Collides with approved booking "$localTitle" ($localSched)';
          } else {
            _slotConflictMessage = null;
          }
        });
      }
      return;
    }

    // 2. Async backend verification (for other dates or unrendered rooms)
    if (mounted) {
      setState(() {
        _isCheckingSlot = true;
        _hasSlotConflict = false;
        _slotConflictMessage = null;
      });
    }

    try {
      final startFormatted = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
      final endFormatted = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';
      final res = await SpaceBookingApiService.instance.checkSlotAvailability(
        roomId: roomId,
        date: _bookingDate,
        startTime: startFormatted,
        endTime: endFormatted,
        setupMinutes: _setupMinutes,
        cleanupMinutes: _cleanupMinutes,
        excludeBookingId: widget.initialItem?.id,
      );

      if (mounted) {
        setState(() {
          _isCheckingSlot = false;
          _hasSlotConflict = res['has_conflict'] == true;
          if (_hasSlotConflict) {
            _slotConflictMessage = res['message']?.toString() ?? 'Room already booked for this time window.';
          } else {
            _slotConflictMessage = null;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingSlot = false);
    }
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    final dt = DateTime.tryParse(dateStr);
    if (dt != null) return dt;
    try {
      return DateFormat('d MMM yyyy').parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat('dd MMM yyyy').parse(dateStr);
    } catch (_) {}
    try {
      return DateFormat('dd-MM-yyyy').parse(dateStr);
    } catch (_) {}
    return null;
  }

  TimeOfDay? _parseTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    final clean = timeStr.trim().toUpperCase();
    final ampmMatch = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(clean);
    if (ampmMatch != null) {
      int h = int.parse(ampmMatch.group(1)!);
      final m = int.parse(ampmMatch.group(2)!);
      final period = ampmMatch.group(3)!;
      if (period == 'PM' && h != 12) h += 12;
      if (period == 'AM' && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    }
    final militaryMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clean);
    if (militaryMatch != null) {
      final h = int.parse(militaryMatch.group(1)!);
      final m = int.parse(militaryMatch.group(2)!);
      return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  Future<void> _loadInitialDetails(String bookingId) async {
    try {
      final details = await SpaceBookingApiService.instance.getDetails(bookingId);
      if (details != null && mounted) {
        setState(() {
          if (details['organizer_email'] != null && (details['organizer_email'] as String).isNotEmpty) {
            _organizerEmailCtrl.text = details['organizer_email'] as String;
          }
          if (details['organizer_phone'] != null && (details['organizer_phone'] as String).isNotEmpty) {
            _organizerPhoneCtrl.text = details['organizer_phone'] as String;
          }
          if (details['special_instructions'] != null && (details['special_instructions'] as String).isNotEmpty) {
            _specialInstructionsCtrl.text = details['special_instructions'] as String;
          }
          if (_descCtrl.text.isEmpty && details['description'] != null) {
            _descCtrl.text = details['description'] as String;
          }
          if (details['setup_minutes'] is int) {
            _setupMinutes = details['setup_minutes'] as int;
          }
          if (details['cleanup_minutes'] is int) {
            _cleanupMinutes = details['cleanup_minutes'] as int;
          }
          if (details['requested_by'] != null) {
            _requesterUserId = details['requested_by']?.toString();
          }
          if (details['amenities_required'] is List) {
            final amList = (details['amenities_required'] as List).map((e) => e.toString().toLowerCase()).toList();
            _projector = amList.any((a) => a.contains('projector'));
            _audioMic = amList.any((a) => a.contains('audio') || a.contains('mic'));
            _whiteboard = amList.any((a) => a.contains('whiteboard'));
            _videoConferencing = amList.any((a) => a.contains('video') || a.contains('conference'));
          }
        });
      }
    } catch (_) {}
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

  Future<void> _fetchRequesters(String query) async {
    setState(() => _isLoadingRequesters = true);
    try {
      final list = await SpaceBookingApiService.instance.getRequesters(search: query);
      if (mounted) {
        setState(() {
          _requesters = list;
          _isLoadingRequesters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequesters = false);
    }
  }

  void _selectRequester(SpaceRequesterProfile profile) {
    setState(() {
      _selectedRequester = profile;
      _requesterUserId = profile.id;
      _organizerNameCtrl.text = profile.fullName;
      if (profile.email.isNotEmpty) _organizerEmailCtrl.text = profile.email;
      if (profile.phone.isNotEmpty) _organizerPhoneCtrl.text = profile.phone;
      if (profile.role.isNotEmpty) {
        final matchRole = _organizerRoles.firstWhere(
          (r) => r.toLowerCase().contains(profile.role.toLowerCase()),
          orElse: () => _organizerRole,
        );
        _organizerRole = matchRole;
      }
      _showRequesterDropdown = false;
    });
  }

  void _clearSelectedRequester() {
    setState(() {
      _selectedRequester = null;
      _requesterUserId = null;
      _organizerNameCtrl.clear();
      _organizerEmailCtrl.clear();
      _organizerPhoneCtrl.clear();
      _showRequesterDropdown = false;
    });
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
    _requesterSearchCtrl.dispose();
    super.dispose();
  }

  List<int> _convertDaysToIntegers(List<String> days) {
    const map = {'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7};
    return days.map((d) => map[d] ?? 1).toList()..sort();
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }

  String _buildRecurrenceSummary() {
    if (_recurrenceFreq == 'none') {
      return 'Single booking session (Does not repeat)';
    }
    String summary = '';
    if (_recurrenceFreq == 'daily') {
      summary = _recurrenceInterval == 1 ? 'Repeats every day' : 'Repeats every $_recurrenceInterval days';
    } else if (_recurrenceFreq == 'weekdays') {
      summary = 'Repeats every weekday (Monday to Friday)';
    } else if (_recurrenceFreq == 'weekly') {
      summary = _recurrenceInterval == 1
          ? 'Repeats weekly on ${_recurrenceDays.join(", ")}'
          : 'Repeats every $_recurrenceInterval weeks on ${_recurrenceDays.join(", ")}';
    } else if (_recurrenceFreq == 'monthly') {
      summary = _recurrenceInterval == 1 ? 'Repeats every month' : 'Repeats every $_recurrenceInterval months';
    } else if (_recurrenceFreq == 'yearly') {
      summary = 'Repeats annually';
    } else {
      summary = 'Repeats on ${_recurrenceDays.join(", ")} (Custom interval $_recurrenceInterval)';
    }

    final dateStr = DateFormat('dd MMM yyyy').format(_bookingDate);
    final timeStr = '${_formatTimeOfDay(_startTime)} – ${_formatTimeOfDay(_endTime)}';

    if (_recurrenceEndType == 'never') {
      summary += ' starting $dateStr ($timeStr) indefinitely';
    } else if (_recurrenceEndType == 'count') {
      summary += ' starting $dateStr ($timeStr) for $_recurrenceCount occurrences';
    } else if (_recurrenceEndType == 'date') {
      summary += ' starting $dateStr ($timeStr) until ${DateFormat('dd MMM yyyy').format(_recurrenceUntilDate)}';
    }
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spaceBookingProvider);
    final notifier = ref.read(spaceBookingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 700;
    final dialogWidth = math.min(820.0, screenWidth * 0.96);

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    const primaryColor = Color(0xFF2563EB);

    if (_selectedRoomId == null && state.bookableRooms.isNotEmpty) {
      _selectedRoomId = state.bookableRooms.first.id;
    }

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dialogBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Dialog Header with Title, Close Button & Subtitle
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.meeting_room_outlined, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.initialItem == null ? 'Book a Campus Space' : 'Edit Space Booking',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_recurrenceFreq != 'none') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Recurring Series',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Configure room selection, timings, recurrence settings, and requester information',
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
              const SizedBox(height: 16),

              // 2. Tab Navigation Bar (Space & Schedule | Recurrence | Requester & Contact | Amenities)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton(0, 'Space & Timings', Icons.schedule_rounded, isDark, primaryColor),
                      _buildTabButton(
                        1,
                        _recurrenceFreq == 'none' ? 'Recurrence' : 'Recurrence (Active)',
                        Icons.repeat_rounded,
                        isDark,
                        primaryColor,
                        hasBadge: _recurrenceFreq != 'none',
                      ),
                      _buildTabButton(
                        2,
                        _selectedRequester != null ? 'Requester (Selected)' : 'Requester & Contact',
                        Icons.person_search_rounded,
                        isDark,
                        primaryColor,
                        hasBadge: _selectedRequester != null,
                      ),
                      _buildTabButton(3, 'Amenities & Notes', Icons.devices_other_rounded, isDark, primaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Tab Body
              Expanded(
                child: SingleChildScrollView(
                  child: _buildActiveTabContent(state, isDark, textPrimary, textSecondary, inputBg, inputBorder, primaryColor, isMobile),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Dialog Footer Actions
              Divider(color: dialogBorder, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (_currentTabIndex > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentTabIndex--),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: dialogBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  if (_currentTabIndex < 3)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentTabIndex++),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Next Step'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: dialogBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) {
                              setState(() => _currentTabIndex = 0); // Jump back to form to fix errors
                              return;
                            }

                            if (_hasSlotConflict) {
                              final proceed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                                      SizedBox(width: 8),
                                      Text('Time Slot Conflict Detected', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  content: Text(
                                    '${_slotConflictMessage ?? "A conflicting approved booking was found for this time slot."}\n\nNotice: Submitting will register this request as a Pending request for review, and it will NOT appear on the space schedule until approved.',
                                    style: TextStyle(fontSize: 13, color: textPrimary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Adjust Timings'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Submit Request Anyway'),
                                    ),
                                  ],
                                ),
                              );
                              if (proceed != true) return;
                            }

                            final startFormatted = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
                            final endFormatted = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

                            final payload = <String, dynamic>{
                              'id': widget.initialItem?.id,
                              'title': _titleCtrl.text.trim(),
                              'description': _descCtrl.text.trim(),
                              'purpose': _purpose,
                              'category': _category,
                              'priority': _priority,
                              'room_id': _selectedRoomId,
                              'booking_date': DateFormat('yyyy-MM-dd').format(_bookingDate),
                              'start_time': startFormatted,
                              'end_time': endFormatted,
                              'setup_minutes': _setupMinutes,
                              'cleanup_minutes': _cleanupMinutes,
                              'organizer_name': _organizerNameCtrl.text.trim(),
                              'organizer_role': _organizerRole,
                              'organizer_email': _organizerEmailCtrl.text.trim(),
                              'organizer_phone': _organizerPhoneCtrl.text.trim(),
                              'requested_by': _requesterUserId,
                              'attendee_count': int.tryParse(_attendeesCtrl.text.trim()) ?? 30,
                              'special_instructions': _specialInstructionsCtrl.text.trim(),
                              'amenities_required': [
                                if (_projector) 'Projector',
                                if (_audioMic) 'Audio System',
                                if (_whiteboard) 'Whiteboard',
                                if (_videoConferencing) 'Video Conferencing',
                              ],
                            };

                            // Recurrence settings payload
                            if (_recurrenceFreq != 'none') {
                              payload['is_recurring'] = true;
                              payload['recurrence'] = {
                                'frequency': _recurrenceFreq,
                                'interval': _recurrenceInterval,
                                'days_of_week': _recurrenceFreq == 'daily'
                                    ? [1, 2, 3, 4, 5, 6, 7]
                                    : (_recurrenceFreq == 'weekdays' ? [1, 2, 3, 4, 5] : _convertDaysToIntegers(_recurrenceDays)),
                                'end_type': _recurrenceEndType,
                                'count': _recurrenceCount,
                                'until_date': DateFormat('yyyy-MM-dd').format(_recurrenceUntilDate),
                              };
                            }

                            final nav = Navigator.of(context);
                            final scf = ScaffoldMessenger.of(context);
                            final res = await notifier.submitBooking(payload);
                            if (!mounted) return;

                            if (res['success'] == true) {
                              nav.pop();
                              scf.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _recurrenceFreq != 'none'
                                        ? 'Recurring space booking series generated successfully!'
                                        : 'Space booking request saved successfully!',
                                  ),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            } else {
                              final msg = res['message']?.toString() ?? 'Failed to save space booking';
                              final isConflict = res['conflict'] == true ||
                                  msg.toLowerCase().contains('conflict') ||
                                  msg.toLowerCase().contains('already booked');

                              if (isConflict) {
                                final roomItem = state.bookableRooms.cast<BookableRoomItem?>().firstWhere(
                                      (r) => r?.id == _selectedRoomId,
                                      orElse: () => null,
                                    );
                                if (!mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (ctx) => SpaceConflictWarningDialog(
                                    roomName: roomItem?.name ?? 'Selected Room',
                                    requestedTime: '$startFormatted - $endFormatted',
                                    conflictMessage: msg,
                                    onChangeTime: () => Navigator.pop(ctx),
                                  ),
                                );
                              } else {
                                scf.showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: state.isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_recurrenceFreq != 'none' ? Icons.repeat_rounded : Icons.check_circle_outline, size: 18),
                    label: Text(
                      state.isSubmitting
                          ? 'Processing...'
                          : widget.initialItem == null
                              ? (_recurrenceFreq != 'none' ? 'Generate Series' : 'Submit Request')
                              : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
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

  Widget _buildTabButton(int index, String title, IconData icon, bool isDark, Color primaryColor, {bool hasBadge = false}) {
    final isSelected = _currentTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (hasBadge) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(
    SpaceBookingState state,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color inputBorder,
    Color primaryColor,
    bool isMobile,
  ) {
    switch (_currentTabIndex) {
      case 0:
        return _buildSpaceAndScheduleTab(state, isDark, textPrimary, textSecondary, inputBg, inputBorder, primaryColor, isMobile);
      case 1:
        return _buildRecurrenceTab(isDark, textPrimary, textSecondary, inputBg, inputBorder, primaryColor, isMobile);
      case 2:
        return _buildRequesterTab(isDark, textPrimary, textSecondary, inputBg, inputBorder, primaryColor, isMobile);
      case 3:
        return _buildAmenitiesTab(isDark, textPrimary, textSecondary, inputBg, inputBorder, primaryColor);
      default:
        return const SizedBox();
    }
  }

  // ==========================================================================
  // TAB 1: SPACE & SCHEDULE
  // ==========================================================================
  Widget _buildSpaceAndScheduleTab(
    SpaceBookingState state,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color inputBorder,
    Color primaryColor,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile) ...[
          _buildFormField(
            label: 'Booking Title *',
            color: textSecondary,
            child: TextFormField(
              controller: _titleCtrl,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: _inputDecoration('e.g. Mathematics Seminar / Annual Workshop', isDark, inputBg, inputBorder),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title required' : null,
            ),
          ),
          const SizedBox(height: 12),
          _buildFormField(
            label: 'Purpose *',
            color: textSecondary,
            child: DropdownButtonFormField<String>(
              initialValue: _purpose,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    decoration: _inputDecoration('e.g. Mathematics Seminar / Annual Workshop', isDark, inputBg, inputBorder),
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
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
        const SizedBox(height: 14),

        // Room Dropdown
        _buildFormField(
          label: 'Select Space / Room *',
          color: textSecondary,
          child: DropdownButtonFormField<String>(
            initialValue: state.bookableRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: _inputDecoration('Choose from bookable campus spaces', isDark, inputBg, inputBorder),
            items: state.bookableRooms.map((r) {
              return DropdownMenuItem(
                value: r.id,
                child: Text(
                  '${r.name} (${r.roomType}) • ${r.buildingName} • Capacity: ${r.maxCapacity} seats',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _selectedRoomId = v);
              _checkLiveSlotStatus();
            },
            validator: (v) => v == null ? 'Room required' : null,
          ),
        ),
        const SizedBox(height: 14),

        // Date & Times
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildFormField(
                label: 'Booking Date *',
                color: textSecondary,
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _bookingDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) {
                      setState(() => _bookingDate = d);
                      _checkLiveSlotStatus();
                    }
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
                        const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd MMM yyyy').format(_bookingDate), style: TextStyle(fontSize: 13, color: textPrimary)),
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
                    if (t != null) {
                      setState(() => _startTime = t);
                      _checkLiveSlotStatus();
                    }
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
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF3B82F6)),
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
                    if (t != null) {
                      setState(() => _endTime = t);
                      _checkLiveSlotStatus();
                    }
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
                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF3B82F6)),
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
        const SizedBox(height: 14),

        // Live Free/Busy & Real-time Conflict Card
        _buildLiveSlotAvailabilityCard(isDark, textPrimary, textSecondary),
        const SizedBox(height: 14),

        // Buffers & Attendees
        Row(
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Setup Buffer',
                color: textSecondary,
                child: DropdownButtonFormField<int>(
                  initialValue: _setupMinutes,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0 mins')),
                    DropdownMenuItem(value: 5, child: Text('5 mins')),
                    DropdownMenuItem(value: 10, child: Text('10 mins')),
                    DropdownMenuItem(value: 15, child: Text('15 mins')),
                    DropdownMenuItem(value: 30, child: Text('30 mins')),
                  ],
                  onChanged: (v) {
                    setState(() => _setupMinutes = v ?? 10);
                    _checkLiveSlotStatus();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'Cleanup Buffer',
                color: textSecondary,
                child: DropdownButtonFormField<int>(
                  initialValue: _cleanupMinutes,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0 mins')),
                    DropdownMenuItem(value: 5, child: Text('5 mins')),
                    DropdownMenuItem(value: 10, child: Text('10 mins')),
                    DropdownMenuItem(value: 15, child: Text('15 mins')),
                    DropdownMenuItem(value: 30, child: Text('30 mins')),
                  ],
                  onChanged: (v) {
                    setState(() => _cleanupMinutes = v ?? 10);
                    _checkLiveSlotStatus();
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'Estimated Attendees',
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
      ],
    );
  }

  // ==========================================================================
  // REAL-TIME FREE / BUSY SLOT AVAILABILITY CARD
  // ==========================================================================
  Widget _buildLiveSlotAvailabilityCard(bool isDark, Color textPrimary, Color textSecondary) {
    if (_isCheckingSlot) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            Text(
              'Checking live slot availability and conflicts...',
              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_hasSlotConflict) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.6 : 0.4), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Slot Busy • Time Conflict Detected',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('COLLISION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _slotConflictMessage ?? 'Overlaps with an approved booking for this space and time window.',
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Please adjust your start/end time or choose another campus space.',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.4 : 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Slot Free & Available',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('AVAILABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'No conflicts detected. Space is available for the selected schedule.',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 2: RECURRENCE SETTINGS (10X CALENDAR GRADE)
  // ==========================================================================
  Widget _buildRecurrenceTab(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color inputBorder,
    Color primaryColor,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Series Anchor Base Schedule Card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Series Base Schedule (Anchor)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Start date & slot being repeated',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isMobile) ...[
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _bookingDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) {
                      setState(() => _bookingDate = d);
                      _checkLiveSlotStatus();
                    }
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: inputBg,
                      border: Border.all(color: inputBorder),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, dd MMM yyyy').format(_bookingDate),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _startTime);
                          if (t != null) {
                            setState(() => _startTime = t);
                            _checkLiveSlotStatus();
                          }
                        },
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border.all(color: inputBorder),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Text(_formatTimeOfDay(_startTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('–', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _endTime);
                          if (t != null) {
                            setState(() => _endTime = t);
                            _checkLiveSlotStatus();
                          }
                        },
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border.all(color: inputBorder),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Text(_formatTimeOfDay(_endTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
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
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _bookingDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (d != null) {
                            setState(() => _bookingDate = d);
                            _checkLiveSlotStatus();
                          }
                        },
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border.all(color: inputBorder),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('EEE, dd MMM yyyy').format(_bookingDate),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _startTime);
                          if (t != null) {
                            setState(() => _startTime = t);
                            _checkLiveSlotStatus();
                          }
                        },
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border.all(color: inputBorder),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Text(_formatTimeOfDay(_startTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('–', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _endTime);
                          if (t != null) {
                            setState(() => _endTime = t);
                            _checkLiveSlotStatus();
                          }
                        },
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border.all(color: inputBorder),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Text(_formatTimeOfDay(_endTime), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _buildFormField(
          label: 'Repeat Frequency',
          color: textSecondary,
          child: DropdownButtonFormField<String>(
            initialValue: _recurrenceFreq,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: _inputDecoration('', isDark, inputBg, inputBorder),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Does not repeat (Single booking)')),
              DropdownMenuItem(value: 'daily', child: Text('Daily (Every day / N days)')),
              DropdownMenuItem(value: 'weekdays', child: Text('Every Weekday (Mon to Fri)')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly (Chosen days)')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly (Every month)')),
              DropdownMenuItem(value: 'yearly', child: Text('Annually (Every year)')),
              DropdownMenuItem(value: 'custom', child: Text('Custom Recurrence...')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _recurrenceFreq = val;
                  if (val == 'weekdays') {
                    _recurrenceDays = ['MO', 'TU', 'WE', 'TH', 'FR'];
                    _recurrenceInterval = 1;
                  } else if (val == 'weekly' && _recurrenceDays.isEmpty) {
                    _recurrenceDays = ['MO', 'WE', 'FR'];
                  }
                });
              }
            },
          ),
        ),

        if (_recurrenceFreq != 'none') ...[
          const SizedBox(height: 16),

          // Day of week chips for weekly or custom
          if (_recurrenceFreq == 'weekly' || _recurrenceFreq == 'custom') ...[
            Text('Repeat on Days of Week', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].map((d) {
                final isSel = _recurrenceDays.contains(d);
                return FilterChip(
                  label: Text(d),
                  selected: isSel,
                  selectedColor: primaryColor,
                  checkmarkColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSel ? Colors.white : textPrimary,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _recurrenceDays.add(d);
                      } else {
                        if (_recurrenceDays.length > 1) {
                          _recurrenceDays.remove(d);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Repeat Interval Stepper
          if (_recurrenceFreq != 'weekdays') ...[
            Text('Repeat Interval', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Repeat every:',
                  style: TextStyle(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF3B82F6), size: 22),
                  onPressed: () {
                    if (_recurrenceInterval > 1) setState(() => _recurrenceInterval--);
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: inputBorder),
                  ),
                  child: Text(
                    '$_recurrenceInterval',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 22),
                  onPressed: () {
                    if (_recurrenceInterval < 52) setState(() => _recurrenceInterval++);
                  },
                ),
                Text(
                  _recurrenceFreq == 'daily' ? 'day(s)' : (_recurrenceFreq == 'monthly' ? 'month(s)' : 'week(s)'),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Recurrence Ends
          Text('Recurrence Ends', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary)),
          const SizedBox(height: 6),
          RadioListTile<String>(
            value: 'never',
            groupValue: _recurrenceEndType,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('Never (Repeats indefinitely)', style: TextStyle(fontSize: 13, color: textPrimary)),
            onChanged: (v) => setState(() => _recurrenceEndType = v ?? 'never'),
          ),
          RadioListTile<String>(
            value: 'count',
            groupValue: _recurrenceEndType,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Row(
              children: [
                Text('After: ', style: TextStyle(fontSize: 13, color: textPrimary)),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () {
                    if (_recurrenceCount > 1) setState(() => _recurrenceCount--);
                  },
                ),
                Text('$_recurrenceCount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  onPressed: () {
                    if (_recurrenceCount < 100) setState(() => _recurrenceCount++);
                  },
                ),
                Text(' occurrences', style: TextStyle(fontSize: 13, color: textPrimary)),
              ],
            ),
            onChanged: (v) => setState(() => _recurrenceEndType = v ?? 'count'),
          ),
          RadioListTile<String>(
            value: 'date',
            groupValue: _recurrenceEndType,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Row(
              children: [
                Text('On specific date: ', style: TextStyle(fontSize: 13, color: textPrimary)),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceUntilDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _recurrenceUntilDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: inputBorder),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_recurrenceUntilDate),
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            onChanged: (v) => setState(() => _recurrenceEndType = v ?? 'date'),
          ),
          const SizedBox(height: 14),

          // Recurrence Live Summary Preview Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _buildRecurrenceSummary(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Icon(Icons.event_available_outlined, size: 40, color: textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  'This booking is configured as a single session.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select Daily, Weekly, or Weekdays above if you want to generate a recurring series.',
                  style: TextStyle(fontSize: 11.5, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================================================
  // TAB 3: REQUESTER & CONTACT (DYNAMIC USER DIRECTORY)
  // ==========================================================================
  Widget _buildRequesterTab(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color inputBorder,
    Color primaryColor,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Select Requestor
        Text(
          'Search & Select Requestor from User Directory',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _requesterSearchCtrl,
          style: TextStyle(fontSize: 13, color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Type user name, role, email, or department...',
            hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF3B82F6)),
            suffixIcon: _isLoadingRequesters
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: inputBorder)),
          ),
          onChanged: (val) {
            _fetchRequesters(val);
            setState(() => _showRequesterDropdown = true);
          },
          onTap: () {
            setState(() => _showRequesterDropdown = true);
          },
        ),
        const SizedBox(height: 10),

        // Selected Requester Card (if any)
        if (_selectedRequester != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF3B82F6),
                  child: Text(
                    _selectedRequester!.fullName.isNotEmpty ? _selectedRequester!.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _selectedRequester!.fullName,
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedRequester!.role.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_selectedRequester!.email.isNotEmpty ? _selectedRequester!.email : "No email"} • ${_selectedRequester!.phone.isNotEmpty ? _selectedRequester!.phone : "No phone"}',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _clearSelectedRequester,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: inputBorder),
                  ),
                  child: const Text('Change', style: TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else if (_showRequesterDropdown && _requesters.isNotEmpty) ...[
          // Autocomplete suggestions list
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: inputBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _requesters.take(6).length,
              separatorBuilder: (_, __) => Divider(height: 1, color: inputBorder),
              itemBuilder: (context, index) {
                final p = _requesters[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    child: Text(
                      p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                    ),
                  ),
                  title: Text(p.fullName, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                  subtitle: Text('${p.role} • ${p.email}', style: TextStyle(fontSize: 11, color: textSecondary), overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF3B82F6)),
                  onTap: () => _selectRequester(p),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Organizer Name & Role Details
        Row(
          children: [
            Expanded(
              flex: 3,
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
              flex: 2,
              child: _buildFormField(
                label: 'Organizer Role',
                color: textSecondary,
                child: DropdownButtonFormField<String>(
                  initialValue: _organizerRoles.contains(_organizerRole)
                      ? _organizerRole
                      : (_organizerRoles.isNotEmpty ? _organizerRoles.first : null),
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  decoration: _inputDecoration('', isDark, inputBg, inputBorder),
                  items: _organizerRoles.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _organizerRole = v ?? (_organizerRoles.isNotEmpty ? _organizerRoles.first : 'Faculty')),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Email & Phone
        Row(
          children: [
            Expanded(
              child: _buildFormField(
                label: 'Email Address',
                color: textSecondary,
                child: TextFormField(
                  controller: _organizerEmailCtrl,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  decoration: _inputDecoration('name@institution.edu', isDark, inputBg, inputBorder),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFormField(
                label: 'Contact Phone',
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
    );
  }

  // ==========================================================================
  // TAB 4: AMENITIES & EQUIPMENT
  // ==========================================================================
  Widget _buildAmenitiesTab(
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color inputBg,
    Color inputBorder,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Required Facilities & Audio-Visual Equipment',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _buildAmenityCard('Projector & Screen', Icons.videocam_outlined, _projector, isDark, (v) => setState(() => _projector = v)),
            _buildAmenityCard('Audio System / Microphones', Icons.mic_none_outlined, _audioMic, isDark, (v) => setState(() => _audioMic = v)),
            _buildAmenityCard('Whiteboard & Markers', Icons.edit_note_outlined, _whiteboard, isDark, (v) => setState(() => _whiteboard = v)),
            _buildAmenityCard('Video Conferencing Setup', Icons.laptop_chromebook_outlined, _videoConferencing, isDark, (v) => setState(() => _videoConferencing = v)),
          ],
        ),
        const SizedBox(height: 16),
        _buildFormField(
          label: 'Special Instructions / Requirements',
          color: textSecondary,
          child: TextFormField(
            controller: _specialInstructionsCtrl,
            maxLines: 4,
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: _inputDecoration(
              'Add specific seating arrangement notes, IT setup requirements, AC pre-cooling requests...',
              isDark,
              inputBg,
              inputBorder,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmenityCard(String label, IconData icon, bool selected, bool isDark, Function(bool) onToggle) {
    return InkWell(
      onTap: () => onToggle(!selected),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? (isDark ? Colors.white : const Color(0xFF1E40AF)) : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: selected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Color color, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark, Color fill, Color border) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
    );
  }
}
