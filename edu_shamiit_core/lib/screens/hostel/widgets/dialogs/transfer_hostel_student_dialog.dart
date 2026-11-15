import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';
import '../common/hostel_smooth_spinner.dart';

class TransferHostelStudentDialog extends ConsumerStatefulWidget {
  final HostelStudentRosterItem student;

  const TransferHostelStudentDialog({super.key, required this.student});

  @override
  ConsumerState<TransferHostelStudentDialog> createState() => _TransferHostelStudentDialogState();
}

class _TransferHostelStudentDialogState extends ConsumerState<TransferHostelStudentDialog> {
  String? _targetBuildingId;
  String? _targetRoomType = 'ALL';
  List<HostelLookupItem> _roomTypeLookups = [];
  String? _targetRoomId;
  String? _targetBedId;
  String _targetBedNumber = '1';
  final DateTime _effectiveDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController(text: 'Mutual Room Change Request');
  bool _isSubmitting = false;
  bool _isLoadingRooms = false;
  bool _isLoadingBeds = false;

  List<HostelRoomItem> _availableRooms = [];
  List<HostelBed> _availableBedsInRoom = [];

  @override
  void initState() {
    super.initState();
    final state = ref.read(hostelProvider);
    if (state.structureTree.isNotEmpty) {
      _targetBuildingId = widget.student.hostelId ?? state.structureTree.first.id;
    }
    _loadLookups();
    _loadRooms();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final lookups = await HostelLookupHelper.instance.getActiveLookup('ROOM_TYPE');
      if (mounted && lookups.isNotEmpty) {
        setState(() {
          _roomTypeLookups = [
            const HostelLookupItem(id: 'all', code: 'ALL', label: 'All Room Types'),
            ...lookups,
          ];
        });
      }
    } catch (_) {}
  }

  List<HostelRoomItem> get _filteredRooms {
    return _availableRooms.where((r) {
      // 1. Room Type match
      final matchesType = _targetRoomType == null ||
          _targetRoomType!.isEmpty ||
          _targetRoomType == 'ALL' ||
          r.roomType.trim().toLowerCase() == _targetRoomType!.trim().toLowerCase();

      // 2. ONLY SHOW ROOMS THAT HAVE EMPTY BEDS (> 0 available beds)
      // Rooms with 0 empty beds are strictly excluded
      final hasVacantBeds = r.availableBeds > 0;

      // 3. Exclude the student's current room
      final isCurrentRoom = (widget.student.roomId != null &&
              widget.student.roomId!.isNotEmpty &&
              r.id == widget.student.roomId) ||
          r.roomNumber.trim().toLowerCase() == widget.student.roomNumber.trim().toLowerCase();

      return matchesType && hasVacantBeds && !isCurrentRoom;
    }).toList();
  }

  Future<void> _loadRooms() async {
    if (_targetBuildingId == null) return;
    setState(() => _isLoadingRooms = true);
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final res = await service.getRooms(
        buildingId: _targetBuildingId,
        pageSize: 100,
      );
      if (mounted) {
        final rooms = (res['rooms'] as List<HostelRoomItem>?) ?? [];
        setState(() {
          _availableRooms = rooms;
          _isLoadingRooms = false;
        });
        _syncSelectedRoomAndBeds();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  void _syncSelectedRoomAndBeds() {
    final filtered = _filteredRooms;
    if (filtered.isNotEmpty) {
      if (!_filteredRooms.any((r) => r.id == _targetRoomId)) {
        _targetRoomId = filtered.first.id;
      }
      _loadBedsForSelectedRoom(_targetRoomId);
    } else {
      setState(() {
        _targetRoomId = null;
        _availableBedsInRoom = [];
        _targetBedId = null;
        _targetBedNumber = '';
      });
    }
  }

  Future<void> _loadBedsForSelectedRoom(String? roomId) async {
    if (roomId == null || roomId.isEmpty) {
      if (mounted) {
        setState(() {
          _availableBedsInRoom = [];
          _targetBedId = null;
          _targetBedNumber = '';
          _isLoadingBeds = false;
        });
      }
      return;
    }

    setState(() => _isLoadingBeds = true);
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final detail = await service.getRoomDetail(roomId);
      if (mounted && _targetRoomId == roomId) {
        // ONLY VACANT / AVAILABLE BEDS (status == 'AVAILABLE' / isAvailable == true)
        // Already booked or occupied beds are completely excluded
        var vacantBeds = (detail?.beds ?? [])
            .where((b) => b.isAvailable || b.status.toUpperCase() == 'AVAILABLE')
            .toList();

        // Safety fallback: if room in DB has vacant beds count > 0 but bed items were empty,
        // synthesize available bed items matching availableBeds count
        if (vacantBeds.isEmpty) {
          final roomMatch = _availableRooms.where((r) => r.id == roomId).firstOrNull;
          final freeCount = roomMatch?.availableBeds ?? 0;
          if (freeCount > 0) {
            vacantBeds = List.generate(
              freeCount,
              (i) => HostelBed(
                id: 'bed-$roomId-${i + 1}',
                bedCode: 'Bed ${i + 1}',
                bedType: 'Single',
                status: 'AVAILABLE',
                monthlyFee: roomMatch?.monthlyFee,
              ),
            );
          }
        }

        setState(() {
          _availableBedsInRoom = vacantBeds;
          _isLoadingBeds = false;
          if (vacantBeds.isNotEmpty) {
            if (!_availableBedsInRoom.any((b) => b.id == _targetBedId)) {
              _targetBedId = vacantBeds.first.id;
              _targetBedNumber = vacantBeds.first.bedCode.isNotEmpty
                  ? vacantBeds.first.bedCode
                  : (vacantBeds.first.bedNumber ?? '1');
            }
          } else {
            _targetBedId = null;
            _targetBedNumber = '';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableBedsInRoom = [];
          _targetBedId = null;
          _targetBedNumber = '';
          _isLoadingBeds = false;
        });
      }
    }
  }

  Future<void> _submitTransfer() async {
    if (_targetRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available target room with vacant beds'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_targetBedId == null || _availableBedsInRoom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an available vacant bed in the target room'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(hostelProvider.notifier);

    final payload = {
      'admission_id': widget.student.admissionId,
      'allocation_id': widget.student.allocationId,
      'student_id': widget.student.studentId,
      'target_building_id': _targetBuildingId,
      'target_room_id': _targetRoomId,
      'new_room_id': _targetRoomId,
      'target_bed_id': _targetBedId,
      'new_bed_id': _targetBedId,
      'target_bed_number': _targetBedNumber,
      'effective_date': DateFormat('yyyy-MM-dd').format(_effectiveDate),
      'reason': _reasonController.text.trim(),
    };

    final ok = await notifier.transferStudentBed(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        // Automatically refresh student 360 profile if drawer is open
        await notifier.fetchStudentDetail(widget.student.admissionId);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredRooms = _filteredRooms;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer Room & Bed',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.student.studentName,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Current Allocation Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Room & Bed', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          'Room ${widget.student.roomNumber} · Bed ${widget.student.bedNo}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Occupied', style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target Hostel Building & Room Type Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target Hostel *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: state.structureTree.any((b) => b.id == _targetBuildingId)
                              ? _targetBuildingId
                              : (state.structureTree.isNotEmpty ? state.structureTree.first.id : null),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          items: state.structureTree.map((b) {
                            return DropdownMenuItem<String>(
                              value: b.id,
                              child: Text(
                                b.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _targetBuildingId = val;
                                _loadRooms();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Room Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _roomTypeLookups.any((l) => l.code == _targetRoomType)
                              ? _targetRoomType
                              : 'ALL',
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: (_roomTypeLookups.isNotEmpty
                                  ? _roomTypeLookups
                                  : const [
                                      HostelLookupItem(id: 'all', code: 'ALL', label: 'All Room Types'),
                                      HostelLookupItem(id: 'std', code: 'Standard', label: 'Standard'),
                                      HostelLookupItem(id: 'dlx', code: 'Deluxe', label: 'Deluxe'),
                                    ])
                              .map((l) {
                            return DropdownMenuItem<String>(
                              value: l.code,
                              child: Text(
                                l.label,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _targetRoomType = val;
                                _syncSelectedRoomAndBeds();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Target Room Dropdown (ONLY ROOMS WITH VACANT BEDS & NOT CURRENT ROOM)
              const Text('Target Room *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_isLoadingRooms)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HostelSmoothSpinner(size: 16),
                      SizedBox(width: 8),
                      Text('Loading vacant rooms...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else if (filteredRooms.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No rooms with vacant beds available in this building. Full rooms and current room are hidden.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: filteredRooms.any((r) => r.id == _targetRoomId) ? _targetRoomId : filteredRooms.first.id,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: filteredRooms.map((r) {
                    final avail = (r.id == _targetRoomId && !_isLoadingBeds)
                        ? _availableBedsInRoom.length
                        : r.availableBeds;
                    final cap = r.capacity ?? 0;
                    return DropdownMenuItem<String>(
                      value: r.id,
                      child: Text(
                        'Room ${r.roomNumber} (${r.roomType}) — $avail free of $cap beds • ₹${r.monthlyFee.toInt()}/mo',
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _targetRoomId = val;
                        _loadBedsForSelectedRoom(val);
                      });
                    }
                  },
                ),
              const SizedBox(height: 14),

              // Target Bed Number / Identifier Dropdown (ONLY EMPTY / VACANT BEDS)
              const Text('Bed Number / Identifier *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (_isLoadingBeds)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HostelSmoothSpinner(size: 16),
                      SizedBox(width: 8),
                      Text('Loading vacant beds...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else if (_availableBedsInRoom.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No vacant beds available in this room. Please choose another room.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _availableBedsInRoom.any((b) => b.id == _targetBedId)
                      ? _targetBedId
                      : _availableBedsInRoom.first.id,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _availableBedsInRoom.map((b) {
                    final bedLabel = b.bedCode.isNotEmpty ? b.bedCode : 'Bed ${b.bedNumber ?? b.id}';
                    final bedTypeSuffix = b.bedType.isNotEmpty ? ' (${b.bedType})' : '';
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(
                        '$bedLabel$bedTypeSuffix - Vacant / Available',
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final bed = _availableBedsInRoom.where((b) => b.id == val).firstOrNull;
                      setState(() {
                        _targetBedId = val;
                        _targetBedNumber = bed?.bedCode.isNotEmpty == true
                            ? bed!.bedCode
                            : (bed?.bedNumber ?? val);
                      });
                    }
                  },
                ),
              const SizedBox(height: 14),

              // Reason
              const Text('Transfer Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting || filteredRooms.isEmpty || _availableBedsInRoom.isEmpty
                        ? null
                        : _submitTransfer,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    child: Text(
                      _isSubmitting ? 'Transferring...' : 'Confirm Transfer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
}
