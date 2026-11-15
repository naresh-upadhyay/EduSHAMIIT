import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../providers/hostel_provider.dart';
import '../../../models/hostel_models.dart';
import '../../../services/hostel_lookup_helper.dart';

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class RaiseComplaintDialog extends ConsumerStatefulWidget {
  final String? initialStudentName;
  final String? initialRoomNumber;
  final String? initialHostelName;

  const RaiseComplaintDialog({
    super.key,
    this.initialStudentName,
    this.initialRoomNumber,
    this.initialHostelName,
  });

  @override
  ConsumerState<RaiseComplaintDialog> createState() => _RaiseComplaintDialogState();
}

class _RaiseComplaintDialogState extends ConsumerState<RaiseComplaintDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationTextController = TextEditingController();
  final TextEditingController _equipmentTextController = TextEditingController();
  final TextEditingController _customRoomTextController = TextEditingController();
  late final TextEditingController _reportedByController;

  String _category = 'Plumbing';
  String _priority = 'Medium';

  // Dynamic Location linkage from Rooms & Allocation tab structureTree
  String? _selectedHostelId;
  String _selectedHostelName = '';
  String? _selectedBuildingId;
  String _selectedBuildingName = '';
  String? _selectedFloorId;
  String _selectedFloorName = '';
  String? _selectedRoomId;
  String _selectedRoomNumber = '';
  bool _isCustomRoom = false;

  // Equipment / Asset selection
  String _selectedEquipmentPreset = 'Not Specified / General Room';
  bool _isCustomEquipment = false;

  // Dynamic Preferred Visit Time
  String _preferredVisitTime = 'Morning (09:00 AM - 12:00 PM)';
  List<String> _dynamicVisitTimes = [];
  DateTime? _customVisitDate;
  TimeOfDay? _customVisitTime;
  DateTime? _preferredVisitStart;
  DateTime? _preferredVisitEnd;

  bool _roomEntryPermission = true;
  bool _markRoomMaintenance = false;
  bool _isSubmitting = false;

  final List<String> _attachments = [];
  List<String> _categories = [];
  List<String> _priorities = [];

  static const List<String> _equipmentPresets = [
    'Not Specified / General Room',
    'AC / Air Conditioner',
    'Ceiling Fan',
    'Tube Light / Bulb / Switchboard',
    'Washbasin & Water Tap',
    'Attached Washroom & Plumbing',
    'Geyser / Water Heater',
    'Study Table & Chair',
    'Bed Frame & Mattress',
    'Cupboard / Wardrobe',
    'Door Lock / Handle',
    'Window / Mesh / Curtain Rod',
    'WiFi Router / LAN Port',
    'Water Dispenser / RO Filter',
    'Other / Custom Equipment...',
  ];

  @override
  void initState() {
    super.initState();
    _reportedByController = TextEditingController(text: widget.initialStudentName ?? 'Current User');
    if (widget.initialHostelName != null && widget.initialHostelName!.isNotEmpty) {
      _selectedHostelName = widget.initialHostelName!;
    }
    if (widget.initialRoomNumber != null && widget.initialRoomNumber!.isNotEmpty) {
      _selectedRoomNumber = widget.initialRoomNumber!;
    }

    _generateDynamicVisitTimes();
    _loadLookups();

    // Ensure Rooms & Allocation structureTree is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(hostelProvider).structureTree.isEmpty) {
        ref.read(hostelProvider.notifier).fetchStructureTree();
      }
    });
  }

  void _generateDynamicVisitTimes([List<String>? lookupOptions]) {
    final now = DateTime.now();
    final todayFmt = DateFormat('EEE, dd MMM').format(now);
    final tomorrowFmt = DateFormat('EEE, dd MMM').format(now.add(const Duration(days: 1)));
    final dayAfterFmt = DateFormat('EEE, dd MMM').format(now.add(const Duration(days: 2)));

    final list = <String>[
      'Any Time (Next Available Working Hour)',
      'Immediate / Emergency (Within 1 Hour)',
      'Today ($todayFmt) - Morning (09:00 AM - 12:00 PM)',
      'Today ($todayFmt) - Afternoon (12:00 PM - 04:00 PM)',
      'Today ($todayFmt) - Evening (04:00 PM - 07:00 PM)',
      'Tomorrow ($tomorrowFmt) - Morning (09:00 AM - 12:00 PM)',
      'Tomorrow ($tomorrowFmt) - Afternoon (12:00 PM - 04:00 PM)',
      'Tomorrow ($tomorrowFmt) - Evening (04:00 PM - 07:00 PM)',
      'Day After ($dayAfterFmt) - Morning (09:00 AM - 12:00 PM)',
      'Day After ($dayAfterFmt) - Afternoon (12:00 PM - 04:00 PM)',
    ];

    if (lookupOptions != null && lookupOptions.isNotEmpty) {
      for (final opt in lookupOptions) {
        if (!list.contains(opt)) list.add(opt);
      }
    }

    list.add('Pick Custom Date & Time Slot...');

    setState(() {
      _dynamicVisitTimes = list;
      if (!_dynamicVisitTimes.contains(_preferredVisitTime)) {
        _preferredVisitTime = list.length > 2 ? list[2] : list.first;
      }
    });
  }

  Future<void> _loadLookups() async {
    final cats = await HostelLookupHelper.instance.getLookupLabels('HOSTEL_COMPLAINT_CATEGORY');
    final prios = await HostelLookupHelper.instance.getLookupLabels('HOSTEL_COMPLAINT_PRIORITY');
    final visitLookups = await HostelLookupHelper.instance.getLookupLabels('HOSTEL_PREFERRED_VISIT_TIME');

    if (mounted) {
      setState(() {
        _categories = cats.isNotEmpty
            ? cats
            : [
                'Plumbing',
                'Electrical',
                'Housekeeping',
                'Furniture',
                'AC/Heating',
                'Pest Control',
                'Food & Mess',
                'Security',
                'Internet/WiFi',
                'Other',
              ];
        _priorities = prios.isNotEmpty
            ? prios
            : [
                'Low',
                'Medium',
                'High',
                'Urgent',
                'Critical',
              ];
        if (!_categories.contains(_category) && _categories.isNotEmpty) {
          _category = _categories.first;
        }
        if (!_priorities.contains(_priority) && _priorities.isNotEmpty) {
          _priority = _priorities.first;
        }
      });
      _generateDynamicVisitTimes(visitLookups);
    }
  }

  Future<void> _selectCustomVisitDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _customVisitDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: Color(0xFF2563EB))
                : const ColorScheme.light(primary: Color(0xFF2563EB)),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _customVisitTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (!mounted || pickedTime == null) return;

    final dateFmt = DateFormat('dd MMM yyyy').format(pickedDate);
    final timeFmt = pickedTime.format(context);
    final customLabel = 'Custom: $dateFmt at $timeFmt';

    setState(() {
      _customVisitDate = pickedDate;
      _customVisitTime = pickedTime;
      if (!_dynamicVisitTimes.contains(customLabel)) {
        _dynamicVisitTimes.insert(0, customLabel);
      }
      _preferredVisitTime = customLabel;

      _preferredVisitStart = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _preferredVisitEnd = _preferredVisitStart!.add(const Duration(hours: 2));
    });
  }

  void _calculateVisitTimestamps() {
    if (_preferredVisitStart != null) return;
    final now = DateTime.now();
    final lower = _preferredVisitTime.toLowerCase();

    DateTime targetDate = now;
    if (lower.contains('tomorrow')) {
      targetDate = now.add(const Duration(days: 1));
    } else if (lower.contains('day after')) {
      targetDate = now.add(const Duration(days: 2));
    }

    if (lower.contains('morning')) {
      _preferredVisitStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 9, 0);
      _preferredVisitEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0);
    } else if (lower.contains('afternoon')) {
      _preferredVisitStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 12, 0);
      _preferredVisitEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 16, 0);
    } else if (lower.contains('evening')) {
      _preferredVisitStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 16, 0);
      _preferredVisitEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 19, 0);
    } else if (lower.contains('immediate') || lower.contains('emergency')) {
      _preferredVisitStart = now;
      _preferredVisitEnd = now.add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationTextController.dispose();
    _equipmentTextController.dispose();
    _customRoomTextController.dispose();
    _reportedByController.dispose();
    super.dispose();
  }

  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data')),
          );
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);
      final uploadedUrl = await ref
          .read(hostelProvider.notifier)
          .uploadComplaintAttachment(bytes, file.name);

      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            _attachments.add(uploadedUrl);
          } else {
            _attachments.add(file.name);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    _calculateVisitTimestamps();

    final roomNumberToSubmit = _selectedRoomNumber.isNotEmpty
        ? _selectedRoomNumber
        : (_customRoomTextController.text.trim().isNotEmpty
            ? _customRoomTextController.text.trim()
            : 'General Room');

    final payload = {
      'academic_year': ref.read(hostelProvider).selectedAcademicYear,
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'category': _category,
      'priority': _priority.toUpperCase(),
      'hostel_id': _selectedHostelId,
      'hostel_name': _selectedHostelName,
      'building_id': _selectedBuildingId,
      'building_name': _selectedBuildingName,
      'floor_id': _selectedFloorId,
      'floor_name': _selectedFloorName,
      'room_id': _selectedRoomId,
      'room_number': roomNumberToSubmit,
      'location_text': _locationTextController.text.trim().isNotEmpty
          ? _locationTextController.text.trim()
          : '$_selectedHostelName, $_selectedFloorName, Room $roomNumberToSubmit',
      'equipment_name': _equipmentTextController.text.trim().isNotEmpty
          ? _equipmentTextController.text.trim()
          : null,
      'reported_by_name': _reportedByController.text.trim(),
      'preferred_visit_time_text': _preferredVisitTime,
      if (_preferredVisitStart != null)
        'preferred_visit_start': _preferredVisitStart!.toIso8601String(),
      if (_preferredVisitEnd != null)
        'preferred_visit_end': _preferredVisitEnd!.toIso8601String(),
      'room_entry_permission': _roomEntryPermission,
      'attachments': _attachments,
    };

    final success = await ref.read(hostelProvider.notifier).createComplaint(payload);

    if (mounted) {
      if (success && _markRoomMaintenance && _selectedRoomId != null) {
        await ref.read(hostelProvider.notifier).service.saveRoom({'id': _selectedRoomId, 'status': 'MAINTENANCE'});
        await ref.read(hostelProvider.notifier).fetchRooms();
      }
      setState(() => _isSubmitting = false);
      if (success && mounted) {
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

    final tree = ref.watch(hostelProvider).structureTree;

    // 1. Resolve Active Building / Hostel from Rooms & Allocation tab
    HostelBuilding? currentBuilding;
    if (tree.isNotEmpty) {
      if (_selectedHostelId != null) {
        currentBuilding = tree.firstWhereOrNull((b) => b.id == _selectedHostelId);
      }
      if (currentBuilding == null && _selectedHostelName.isNotEmpty) {
        currentBuilding = tree.firstWhereOrNull((b) => b.name.toLowerCase() == _selectedHostelName.toLowerCase());
      }
      if (currentBuilding == null) {
        final provBuildingId = ref.read(hostelProvider).selectedBuildingId;
        if (provBuildingId != null) {
          currentBuilding = tree.firstWhereOrNull((b) => b.id == provBuildingId);
        }
      }
      currentBuilding ??= tree.first;

      _selectedHostelId = currentBuilding.id;
      _selectedHostelName = currentBuilding.name;
      _selectedBuildingId = currentBuilding.id;
      if (_selectedBuildingName.isEmpty) {
        _selectedBuildingName = currentBuilding.code.isNotEmpty ? currentBuilding.code : currentBuilding.name;
      }
    }

    // 2. Resolve Active Floor for currentBuilding
    final availableFloors = currentBuilding?.floors ?? [];
    HostelFloor? currentFloor;
    if (availableFloors.isNotEmpty) {
      if (_selectedFloorId != null) {
        currentFloor = availableFloors.firstWhereOrNull((f) => f.id == _selectedFloorId);
      }
      if (currentFloor == null && _selectedFloorName.isNotEmpty) {
        currentFloor = availableFloors.firstWhereOrNull((f) => f.floorName.toLowerCase() == _selectedFloorName.toLowerCase());
      }
      if (currentFloor == null && widget.initialRoomNumber != null) {
        currentFloor = availableFloors.firstWhereOrNull(
          (f) => f.rooms.any((r) => r.roomNumber.toLowerCase() == widget.initialRoomNumber!.toLowerCase()),
        );
      }
      currentFloor ??= availableFloors.firstWhereOrNull((f) => f.rooms.isNotEmpty) ?? availableFloors.first;

      _selectedFloorId = currentFloor.id;
      _selectedFloorName = currentFloor.floorName;
    } else {
      _selectedFloorId = null;
      _selectedFloorName = '';
    }

    // 3. Resolve Active Room for currentFloor
    final availableRooms = currentFloor?.rooms ?? [];
    HostelTreeRoom? currentRoom;
    if (availableRooms.isNotEmpty) {
      if (!_isCustomRoom) {
        if (_selectedRoomId != null) {
          currentRoom = availableRooms.firstWhereOrNull((r) => r.id == _selectedRoomId);
        }
        if (currentRoom == null && _selectedRoomNumber.isNotEmpty) {
          currentRoom = availableRooms.firstWhereOrNull((r) => r.roomNumber.toLowerCase() == _selectedRoomNumber.toLowerCase());
        }
        currentRoom ??= availableRooms.first;

        _selectedRoomId = currentRoom.id;
        _selectedRoomNumber = currentRoom.roomNumber;
      }
    } else {
      _selectedRoomId = null;
      if (!_isCustomRoom) {
        _selectedRoomNumber = '';
      }
    }

    // 4. Resolve Building / Block options
    final blockOptions = <String>{
      if (_selectedBuildingName.isNotEmpty) _selectedBuildingName,
      if (currentBuilding != null && currentBuilding.code.isNotEmpty) currentBuilding.code,
      if (currentBuilding != null && currentBuilding.name.isNotEmpty) currentBuilding.name,
      ...?currentBuilding?.floors.map((f) => f.wing).where((w) => w != null && w.isNotEmpty).cast<String>(),
    }.toList();
    if (blockOptions.isEmpty) blockOptions.add('Block A');
    if (!blockOptions.contains(_selectedBuildingName)) {
      _selectedBuildingName = blockOptions.first;
    }

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.report_problem_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raise New Complaint',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Report an issue, maintenance requirement, or grievance in the hostel premises.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: textSecondary,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text('Complaint Title *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Water leakage in bathroom tap / AC not cooling',
                          hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 16),

                      // Category and Priority Row
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 500;
                          final categoryField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _category,
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
                                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _category = v);
                                },
                              ),
                            ],
                          );

                          final priorityField = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _priority,
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
                                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _priority = v);
                                },
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                categoryField,
                                const SizedBox(height: 12),
                                priorityField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: categoryField),
                              const SizedBox(width: 14),
                              Expanded(child: priorityField),
                            ],
                          );
                        },
                      ),

                      if (_priority.toLowerCase() == 'urgent' || _priority.toLowerCase() == 'critical') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.build_circle_outlined, size: 22, color: Color(0xFFDC2626)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Mark Room as MAINTENANCE',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                    ),
                                    Text(
                                      'Temporarily blocks new bed allocations while critical issue is repaired',
                                      style: TextStyle(fontSize: 11, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _markRoomMaintenance,
                                activeThumbColor: const Color(0xFFDC2626),
                                onChanged: (v) => setState(() => _markRoomMaintenance = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Smart Location Section Header (Rooms & Allocation Sync Badge)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(Icons.domain_rounded, size: 16, color: Color(0xFF2563EB)),
                          Text('Hostel Location & Asset Linkage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Rooms & Allocation Sync',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Location details are populated dynamically from your institution structure. No manual typing required.',
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                      const SizedBox(height: 12),

                      // Location Cascading Dropdowns
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 520;

                          // 1. Hostel Dropdown
                          final hostelField = DropdownButtonFormField<String>(
                            initialValue: _selectedHostelId,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Hostel',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: tree.isEmpty
                                ? [DropdownMenuItem(value: _selectedHostelId, child: Text(_selectedHostelName.isNotEmpty ? _selectedHostelName : 'Loading Hostels...'))]
                                : tree.map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                                    )).toList(),
                            onChanged: tree.isEmpty
                                ? null
                                : (newBuildingId) {
                                    if (newBuildingId != null) {
                                      final b = tree.firstWhereOrNull((el) => el.id == newBuildingId);
                                      if (b != null) {
                                        setState(() {
                                          _selectedHostelId = b.id;
                                          _selectedHostelName = b.name;
                                          _selectedBuildingId = b.id;
                                          _selectedBuildingName = b.code.isNotEmpty ? b.code : b.name;
                                          _selectedFloorId = null;
                                          _selectedFloorName = '';
                                          _selectedRoomId = null;
                                          _selectedRoomNumber = '';
                                          _isCustomRoom = false;
                                        });
                                      }
                                    }
                                  },
                          );

                          // 2. Building / Block Dropdown
                          final buildingField = DropdownButtonFormField<String>(
                            initialValue: _selectedBuildingName,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Building / Block',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: blockOptions.map((blk) => DropdownMenuItem(
                                  value: blk,
                                  child: Text(blk, overflow: TextOverflow.ellipsis),
                                )).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBuildingName = val);
                            },
                          );

                          // 3. Floor Dropdown
                          final floorField = DropdownButtonFormField<String>(
                            initialValue: _selectedFloorId,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Floor',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: availableFloors.isEmpty
                                ? [const DropdownMenuItem(value: null, child: Text('No Floors Available', style: TextStyle(fontSize: 12)))]
                                : availableFloors.map((f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(
                                        '${f.floorName} (${f.roomsCount} rooms)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )).toList(),
                            onChanged: availableFloors.isEmpty
                                ? null
                                : (newFloorId) {
                                    if (newFloorId != null) {
                                      final f = availableFloors.firstWhereOrNull((el) => el.id == newFloorId);
                                      if (f != null) {
                                        setState(() {
                                          _selectedFloorId = f.id;
                                          _selectedFloorName = f.floorName;
                                          _selectedRoomId = null;
                                          _selectedRoomNumber = '';
                                          _isCustomRoom = false;
                                        });
                                      }
                                    }
                                  },
                          );

                          // 4. Room No. Dropdown
                          final roomField = DropdownButtonFormField<String>(
                            initialValue: _isCustomRoom ? '__CUSTOM__' : _selectedRoomId,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Room No.',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: [
                              ...availableRooms.map((r) {
                                final statusLabel = r.status.toLowerCase() == 'occupied' ? 'Occupied' : 'Available';
                                return DropdownMenuItem<String>(
                                  value: r.id,
                                  child: Text(
                                    '${r.roomNumber} (${r.roomType} • $statusLabel)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                              const DropdownMenuItem<String>(
                                value: '__CUSTOM__',
                                child: Text('+ Common Area / Custom Room', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                              ),
                            ],
                            onChanged: (newRoomVal) {
                              if (newRoomVal == '__CUSTOM__') {
                                setState(() {
                                  _isCustomRoom = true;
                                  _selectedRoomId = null;
                                  _selectedRoomNumber = '';
                                });
                              } else if (newRoomVal != null) {
                                final r = availableRooms.firstWhereOrNull((el) => el.id == newRoomVal);
                                if (r != null) {
                                  setState(() {
                                    _isCustomRoom = false;
                                    _selectedRoomId = r.id;
                                    _selectedRoomNumber = r.roomNumber;
                                  });
                                }
                              }
                            },
                          );

                          // 5. Equipment / Asset Dropdown
                          final equipmentField = DropdownButtonFormField<String>(
                            initialValue: _selectedEquipmentPreset,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Equipment / Asset (Optional)',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                            ),
                            items: _equipmentPresets.map((eq) => DropdownMenuItem(
                                  value: eq,
                                  child: Text(eq, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
                                )).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedEquipmentPreset = v;
                                  _isCustomEquipment = v == 'Other / Custom Equipment...';
                                  if (!_isCustomEquipment) {
                                    _equipmentTextController.text = v == 'Not Specified / General Room' ? '' : v;
                                  }
                                });
                              }
                            },
                          );

                          // 6. Dynamic Preferred Visit Time Dropdown with Calendar Picker Shortcut
                          final visitTimeField = DropdownButtonFormField<String>(
                            initialValue: _preferredVisitTime,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Preferred Visit Time',
                              filled: true,
                              fillColor: fieldBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFF2563EB)),
                                tooltip: 'Pick Exact Date & Time Slot',
                                onPressed: _selectCustomVisitDateTime,
                              ),
                            ),
                            items: _dynamicVisitTimes.map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: t.startsWith('Today') || t.startsWith('Immediate') || t.startsWith('Custom') ? FontWeight.w600 : FontWeight.normal,
                                      color: t.startsWith('Immediate') ? const Color(0xFFDC2626) : textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                if (v == 'Pick Custom Date & Time Slot...') {
                                  _selectCustomVisitDateTime();
                                } else {
                                  setState(() {
                                    _preferredVisitTime = v;
                                    _customVisitDate = null;
                                    _customVisitTime = null;
                                    _preferredVisitStart = null;
                                    _preferredVisitEnd = null;
                                  });
                                }
                              }
                            },
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                hostelField,
                                const SizedBox(height: 10),
                                buildingField,
                                const SizedBox(height: 10),
                                floorField,
                                const SizedBox(height: 10),
                                roomField,
                                if (_isCustomRoom || availableRooms.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _customRoomTextController,
                                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Specify Room No. / Area',
                                      hintText: 'e.g. 1st Floor Corridor / Washroom / Study Room',
                                      hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                    ),
                                    validator: (v) => _isCustomRoom && (v == null || v.trim().isEmpty) ? 'Please specify area or room' : null,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                equipmentField,
                                if (_isCustomEquipment) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _equipmentTextController,
                                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Enter Custom Asset Name',
                                      hintText: 'e.g. Study Table Lamp / Tap #2',
                                      hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                visitTimeField,
                              ],
                            );
                          }

                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: hostelField),
                                  const SizedBox(width: 10),
                                  Expanded(child: buildingField),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: floorField),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        roomField,
                                        if (_isCustomRoom || availableRooms.isEmpty) ...[
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _customRoomTextController,
                                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                                            decoration: InputDecoration(
                                              labelText: 'Specify Room No. / Area',
                                              hintText: 'e.g. 1st Floor Corridor / Washroom / Study Room',
                                              hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                                              filled: true,
                                              fillColor: fieldBg,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                            ),
                                            validator: (v) => _isCustomRoom && (v == null || v.trim().isEmpty) ? 'Please specify area or room' : null,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        equipmentField,
                                        if (_isCustomEquipment) ...[
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _equipmentTextController,
                                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                                            decoration: InputDecoration(
                                              labelText: 'Enter Custom Asset Name',
                                              hintText: 'e.g. Study Table Lamp / Tap #2',
                                              hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                                              filled: true,
                                              fillColor: fieldBg,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: visitTimeField),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text('Detailed Description *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Please describe the problem clearly, including frequency and specific symptoms...',
                          hintStyle: TextStyle(fontSize: 12.5, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                        ),
                        validator: (v) => (v == null || v.trim().length < 5) ? 'Please provide a descriptive summary' : null,
                      ),
                      const SizedBox(height: 14),

                      // Room entry permission checkbox
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _roomEntryPermission,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _roomEntryPermission = v ?? true),
                            ),
                            Expanded(
                              child: Text(
                                'Grant permission for maintenance technician to enter room in my absence if needed.',
                                style: TextStyle(fontSize: 12, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attachments Section
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text('Attachments & Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                          if (_isUploadingPhoto)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Uploading...', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                                ],
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: _pickAndUploadAttachment,
                              icon: const Icon(Icons.attach_file_rounded, size: 16),
                              label: const Text('Add Document / Photo', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                            ),
                        ],
                      ),
                      if (_attachments.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_attachments.length, (idx) {
                            final rawName = _attachments[idx];
                            final displayName = rawName.contains('/')
                                ? rawName.split('/').last
                                : rawName;
                            final lower = displayName.toLowerCase();
                            final isPdf = lower.endsWith('.pdf');
                            final isImage = lower.endsWith('.jpg') ||
                                lower.endsWith('.jpeg') ||
                                lower.endsWith('.png') ||
                                lower.endsWith('.webp') ||
                                lower.endsWith('.gif');
                            final isDoc = lower.endsWith('.doc') || lower.endsWith('.docx');
                            final chipIcon = isPdf
                                ? Icons.picture_as_pdf_rounded
                                : isImage
                                    ? Icons.image_rounded
                                    : isDoc
                                        ? Icons.description_rounded
                                        : Icons.insert_drive_file_rounded;
                            final chipColor = isPdf
                                ? const Color(0xFFDC2626)
                                : isImage
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF0D9488);
                            return Chip(
                              avatar: Icon(chipIcon, size: 16, color: chipColor),
                              label: Text(
                                displayName.length > 25 ? '${displayName.substring(0, 22)}...' : displayName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              deleteIcon: const Icon(Icons.close_rounded, size: 14),
                              onDeleted: () => _removeAttachment(idx),
                              backgroundColor: fieldBg,
                              side: BorderSide(color: borderColor),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Complaint',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
