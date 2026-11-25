import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';
import '../common/hostel_smooth_spinner.dart';

class AddHostelStudentDialog extends ConsumerStatefulWidget {
  const AddHostelStudentDialog({super.key});

  @override
  ConsumerState<AddHostelStudentDialog> createState() => _AddHostelStudentDialogState();
}

class _AddHostelStudentDialogState extends ConsumerState<AddHostelStudentDialog> {
  int _currentStep = 0;
  bool _isLoadingCandidates = false;
  bool _isSubmitting = false;
  Timer? _searchDebounce;
  int _searchSeq = 0;

  // Step 1: Selected candidate
  EligibleStudentItem? _selectedStudent;
  final TextEditingController _studentSearchController = TextEditingController();
  List<EligibleStudentItem> _candidates = [];

  // Step 2: Admission info
  late String _academicYear;
  DateTime _admissionDate = DateTime.now();
  String? _selectedHostelId;
  String _hostelType = 'Standard';
  List<HostelLookupItem> _roomTypeLookups = [];

  // Step 3: Bed Allocation
  String? _selectedRoomId;
  String? _selectedBedId;
  String _bedCode = '1';
  bool _autoAllocate = true;
  List<HostelRoomItem> _availableRooms = [];
  List<HostelBed> _availableBedsInRoom = [];
  bool _isLoadingBeds = false;

  // Step 4: Fees
  String _feePlan = 'Monthly';
  final TextEditingController _monthlyFeeController = TextEditingController(text: '6000');
  final TextEditingController _depositController = TextEditingController(text: '10000');
  String _feeStatus = 'PAID';
  final TextEditingController _initialPaymentAmountController = TextEditingController(text: '16000');
  List<HostelLookupItem> _feePlanLookups = [];
  List<HostelLookupItem> _initialPaymentStatusLookups = [];

  // Step 5: Emergency & Remarks
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(hostelProvider);
    _academicYear = state.selectedAcademicYear;
    if (state.structureTree.isNotEmpty) {
      _selectedHostelId = state.structureTree.first.id;
    }
    _loadCandidates();
    _loadRoomsForHostel();
    _loadLookups();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _studentSearchController.dispose();
    _monthlyFeeController.dispose();
    _depositController.dispose();
    _initialPaymentAmountController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  List<HostelRoomItem> get _filteredRooms {
    return _availableRooms.where((r) {
      final matchesType = _hostelType.isEmpty || r.roomType.trim().toLowerCase() == _hostelType.trim().toLowerCase();
      // NO NEED TO SHOW ROOM IN LIST WHERE 0 BED IS EMPTY TO ASSIGN
      final hasVacantBeds = r.availableBeds > 0;
      return matchesType && hasVacantBeds;
    }).toList();
  }

  double get _selectedRoomMonthlyFee {
    if (_selectedBedId != null && _availableBedsInRoom.isNotEmpty) {
      final bed = _availableBedsInRoom.where((b) => b.id == _selectedBedId).firstOrNull;
      if (bed != null && bed.monthlyFee != null && bed.monthlyFee! > 0) {
        return bed.monthlyFee!;
      }
    }
    if (_selectedRoomId != null && _availableRooms.isNotEmpty) {
      final match = _availableRooms.where((r) => r.id == _selectedRoomId).firstOrNull;
      if (match != null && match.monthlyFee > 0) {
        return match.monthlyFee;
      }
    }
    final filtered = _filteredRooms;
    if (filtered.isNotEmpty) {
      final firstRoomWithFee = filtered.where((r) => r.monthlyFee > 0).firstOrNull;
      if (firstRoomWithFee != null) {
        return firstRoomWithFee.monthlyFee;
      }
    }
    return 6000.0;
  }

  double _calculatePlanFee(String plan, double baseMonthly) {
    final p = plan.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '_');
    if (p.contains('QUARTERLY')) {
      return ((baseMonthly * 3 * 0.95) / 100).round() * 100.0;
    } else if (p.contains('BI_ANNUAL') || p.contains('BIANNUAL') || p.contains('HALF')) {
      return ((baseMonthly * 6 * 0.90) / 100).round() * 100.0;
    } else if (p.contains('ANNUAL') || p.contains('YEARLY')) {
      return ((baseMonthly * 12 * 0.85) / 100).round() * 100.0;
    }
    return baseMonthly; // Monthly
  }

  void _updateCalculatedFeeAndPayment({bool userEditedPayment = false}) {
    final fee = _calculatePlanFee(_feePlan, _selectedRoomMonthlyFee);
    _monthlyFeeController.text = fee.toStringAsFixed(0);

    if (!userEditedPayment) {
      final deposit = double.tryParse(_depositController.text) ?? 10000.0;
      if (_feeStatus == 'PAID') {
        _initialPaymentAmountController.text = (fee + deposit).toStringAsFixed(0);
      } else if (_feeStatus == 'PENDING' || _feeStatus == 'WAIVED') {
        _initialPaymentAmountController.text = '0';
      } else if (_feeStatus == 'PARTIAL') {
        _initialPaymentAmountController.text = fee.toStringAsFixed(0);
      }
    }
  }

  void _syncSelectedRoomAndBeds() {
    final filtered = _filteredRooms;
    if (filtered.isNotEmpty) {
      final currentMatch = filtered.where((r) => r.id == _selectedRoomId).firstOrNull;
      if (currentMatch == null) {
        // Prefer room with available beds > 0
        final vacantRoom = filtered.where((r) => r.availableBeds > 0).firstOrNull;
        _selectedRoomId = (vacantRoom ?? filtered.first).id;
      }
      _loadBedsForSelectedRoom(_selectedRoomId);
    } else {
      _selectedRoomId = null;
      _availableBedsInRoom = [];
      _selectedBedId = null;
      _bedCode = '';
    }
    _updateCalculatedFeeAndPayment();
  }

  Future<void> _loadBedsForSelectedRoom(String? roomId) async {
    if (roomId == null || roomId.isEmpty) {
      if (mounted) {
        setState(() {
          _availableBedsInRoom = [];
          _selectedBedId = null;
          _bedCode = '';
          _isLoadingBeds = false;
        });
      }
      return;
    }

    setState(() => _isLoadingBeds = true);
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final detail = await service.getRoomDetail(roomId);
      if (mounted && _selectedRoomId == roomId) {
        // ONLY EMPTY / AVAILABLE BEDS (status == 'AVAILABLE' / isAvailable == true)
        // Already booked or occupied beds are completely excluded
        var vacantBeds = (detail?.beds ?? []).where((b) => b.isAvailable).toList();

        // Safety fallback: if room in DB has vacant beds but bed records were not returned,
        // synthesize available beds matching availableBeds count so free rooms never show warning.
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
            if (!_availableBedsInRoom.any((b) => b.id == _selectedBedId)) {
              _selectedBedId = vacantBeds.first.id;
              _bedCode = vacantBeds.first.bedCode.isNotEmpty 
                  ? vacantBeds.first.bedCode 
                  : (vacantBeds.first.bedNumber ?? '1');
            }
          } else {
            _selectedBedId = null;
            _bedCode = '';
          }
          _updateCalculatedFeeAndPayment();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _availableBedsInRoom = [];
          _selectedBedId = null;
          _bedCode = '';
          _isLoadingBeds = false;
        });
      }
    }
  }

  void _onRoomTypeChanged(String newType) {
    setState(() {
      _hostelType = newType;
      _syncSelectedRoomAndBeds();
    });
  }

  Future<void> _loadLookups() async {
    try {
      final roomTypes = await HostelLookupHelper.instance.getActiveLookup('ROOM_TYPE');
      final plans = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_FEE_BILLING_PLAN');
      final statuses = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_INITIAL_FEE_PAYMENT_STATUS');
      if (mounted) {
        setState(() {
          _roomTypeLookups = roomTypes;
          _feePlanLookups = plans;
          _initialPaymentStatusLookups = statuses;

          if (_roomTypeLookups.isNotEmpty) {
            if (!_roomTypeLookups.any((t) => t.label == _hostelType)) {
              final standard = _roomTypeLookups.where((t) => t.label.toLowerCase() == 'standard').firstOrNull;
              _hostelType = standard?.label ?? _roomTypeLookups.first.label;
            }
          }

          if (_feePlanLookups.isNotEmpty && !_feePlanLookups.any((p) => p.label == _feePlan)) {
            _feePlan = _feePlanLookups.first.label;
          }
          if (_initialPaymentStatusLookups.isNotEmpty && !_initialPaymentStatusLookups.any((s) => s.code == _feeStatus)) {
            _feeStatus = _initialPaymentStatusLookups.first.code;
          }
          _syncSelectedRoomAndBeds();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCandidates([String query = '']) async {
    final currentSeq = ++_searchSeq;
    setState(() => _isLoadingCandidates = true);
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final list = await service.getEligibleStudents(
        academicYear: _academicYear,
        search: query,
        limit: 25,
      );
      if (mounted && currentSeq == _searchSeq) {
        setState(() {
          _candidates = list;
          _isLoadingCandidates = false;
        });
      }
    } catch (_) {
      if (mounted && currentSeq == _searchSeq) {
        setState(() => _isLoadingCandidates = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadCandidates(val.trim());
      }
    });
  }

  Future<void> _loadRoomsForHostel() async {
    if (_selectedHostelId == null) return;
    final service = ref.read(hostelProvider.notifier).service;
    try {
      final res = await service.getRooms(
        buildingId: _selectedHostelId,
        status: 'ALL',
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _availableRooms = res['rooms'] as List<HostelRoomItem>;
          _syncSelectedRoomAndBeds();
        });
      }
    } catch (_) {}
  }

  void _onStudentSelected(EligibleStudentItem student) {
    setState(() {
      _selectedStudent = student;
      if (student.phone != null && student.phone!.isNotEmpty) {
        _emergencyContactController.text = '${student.phone} (Parent)';
      }
      if (student.address != null && student.address!.isNotEmpty) {
        _addressController.text = student.address!;
      }
    });
  }

  Future<void> _submitAdmission() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }
    if (_selectedHostelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a hostel')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(hostelProvider.notifier);

    final payload = {
      'student_id': _selectedStudent!.id,
      'hostel_id': _selectedHostelId,
      'academic_year': _academicYear,
      'admission_date': DateFormat('yyyy-MM-dd').format(_admissionDate),
      'hostel_type': _hostelType,
      'fee_plan': _feePlan,
      'monthly_fee': double.tryParse(_monthlyFeeController.text) ?? 6000.0,
      'deposit_amount': double.tryParse(_depositController.text) ?? 10000.0,
      'fee_status': _feeStatus,
      'initial_payment_amount': double.tryParse(_initialPaymentAmountController.text) ?? 0.0,
      'room_id': _autoAllocate ? _selectedRoomId : null,
      'bed_id': _autoAllocate && _selectedBedId != null && !_selectedBedId!.startsWith('bed-')
          ? _selectedBedId
          : null,
      'bed_number': _bedCode,
      'emergency_contact': _emergencyContactController.text.trim(),
      'remarks': _remarksController.text.trim(),
    };

    final ok = await notifier.admitStudent(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Hostel Student Admission',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Step-by-step student onboarding and room bed assignment',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            ),

            // Stepper Header Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepPill(0, '1. Student', Icons.person_outline),
                  _buildStepPill(1, '2. Admission', Icons.apartment_outlined),
                  _buildStepPill(2, '3. Allocation', Icons.bed_outlined),
                  _buildStepPill(3, '4. Fee Plan', Icons.payments_outlined),
                  _buildStepPill(4, '5. Review', Icons.check_circle_outline),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(state, isDark),
              ),
            ),

            // Dialog Footer / Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      if (_currentStep < 4)
                        ElevatedButton(
                          onPressed: () {
                            if (_currentStep == 0 && _selectedStudent == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please choose a student to proceed')),
                              );
                              return;
                            }
                            if (_currentStep == 1 && _selectedHostelId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select a target hostel building')),
                              );
                              return;
                            }
                            if (_currentStep == 2 && _autoAllocate) {
                              if (_filteredRooms.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('No rooms available for Room Type "$_hostelType". Please choose another type or toggle off allocation.')),
                                );
                                return;
                              }
                              if (_selectedRoomId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a room to allocate')),
                                );
                                return;
                              }
                              if (_availableBedsInRoom.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Selected room has no vacant beds. Please select another room or toggle off allocation.')),
                                );
                                return;
                              }
                              if (_selectedBedId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select an available bed')),
                                );
                                return;
                              }
                            }
                            setState(() => _currentStep++);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          child: const Text('Next Step', style: TextStyle(color: Colors.white)),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitAdmission,
                          icon: _isSubmitting
                              ? const HostelSmoothSpinner(size: 16, strokeWidth: 2.0, color: Colors.white)
                              : const Icon(Icons.check, size: 18, color: Colors.white),
                          label: Text(
                            _isSubmitting ? 'Admitting...' : 'Confirm Admission',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill(int index, String label, IconData icon) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return InkWell(
      onTap: () {
        if (_selectedStudent != null || index == 0) {
          if (index > 2 && _autoAllocate && (_selectedRoomId == null || _availableBedsInRoom.isEmpty || _selectedBedId == null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a valid room and vacant bed before proceeding')),
            );
            return;
          }
          setState(() => _currentStep = index);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF16A34A)
                  : (isActive ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(HostelState state, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Student(isDark);
      case 1:
        return _buildStep2Admission(state, isDark);
      case 2:
        return _buildStep3Allocation(isDark);
      case 3:
        return _buildStep4Fees(isDark);
      case 4:
        return _buildStep5Review(state, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Student(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Registered Student',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose an existing enrolled student from the school identity directory (profiles).',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        // Live Search Input
        TextField(
          controller: _studentSearchController,
          decoration: InputDecoration(
            hintText: 'Search by student name or roll number...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
              maxWidth: 44,
              maxHeight: 44,
            ),
            suffixIcon: _isLoadingCandidates
                ? const Center(
                    child: HostelSmoothSpinner(size: 18, strokeWidth: 2.2),
                  )
                : (_studentSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _studentSearchController.clear();
                          _loadCandidates('');
                        },
                      )
                    : null),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 14),

        // Selected Student Preview
        if (_selectedStudent != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  child: Text(
                    _selectedStudent!.fullName.isNotEmpty ? _selectedStudent!.fullName[0] : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStudent!.fullName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                      ),
                      Text(
                        'Roll: ${_selectedStudent!.rollNumber ?? '0101'} | Class: ${_selectedStudent!.className ?? '10 A'} | Gender: ${_selectedStudent!.gender ?? 'Male'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 24),
              ],
            ),
          ),

        // Candidates List
        const Text('Available Candidates:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        if (_isLoadingCandidates && _candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HostelSmoothSpinner(
                    size: 32,
                    strokeWidth: 2.8,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading available candidates...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_candidates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No matching students found', style: TextStyle(color: Color(0xFF94A3B8)))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _candidates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final item = _candidates[i];
              final isSel = _selectedStudent?.id == item.id;
              return ListTile(
                selected: isSel,
                selectedTileColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE2E8F0),
                  child: Text(
                    item.fullName.isNotEmpty ? item.fullName[0] : 'S',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                ),
                title: Text(item.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('Roll: ${item.rollNumber ?? '-'} · Class: ${item.className ?? '-'} · ${item.gender ?? 'Male'}', style: const TextStyle(fontSize: 11)),
                trailing: isSel
                    ? const Icon(Icons.radio_button_checked, color: Color(0xFF2563EB))
                    : const Icon(Icons.radio_button_off, color: Color(0xFF94A3B8)),
                onTap: () => _onStudentSelected(item),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStep2Admission(HostelState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hostel & Admission Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),

        // Academic Year
        const Text('Academic Year', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(_academicYear, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),

        // Hostel Building Dropdown
        const Text('Target Hostel Building *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _selectedHostelId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: state.structureTree.map((b) {
            return DropdownMenuItem<String>(
              value: b.id,
              child: Text('${b.name} (${b.genderPolicy})'),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedHostelId = val;
              _loadRoomsForHostel();
            });
          },
        ),
        const SizedBox(height: 16),

        // Admission Date Picker
        const Text('Admission Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _admissionDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _admissionDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd MMMM yyyy').format(_admissionDate)),
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Room Type (matching Room Type in Room and Allocation popup from ROOM_TYPE lookup)
        const Text('Room Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        const Text(
          'From Lookup Management (ROOM_TYPE). Only rooms matching this type will be selectable.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: _roomTypeLookups.any((t) => t.label == _hostelType)
              ? _hostelType
              : (_roomTypeLookups.isNotEmpty ? _roomTypeLookups.first.label : null),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hintText: 'Select Room Type',
          ),
          items: (_roomTypeLookups.isNotEmpty
                  ? _roomTypeLookups
                  : const [
                      HostelLookupItem(id: '1', code: 'STANDARD', label: 'Standard'),
                      HostelLookupItem(id: '2', code: 'DELUXE', label: 'Deluxe'),
                      HostelLookupItem(id: '3', code: 'SUPER_DELUXE', label: 'Super Deluxe'),
                      HostelLookupItem(id: '4', code: 'DORMITORY', label: 'Dormitory'),
                      HostelLookupItem(id: '5', code: 'SINGLE', label: 'Single Occupancy'),
                    ])
              .map((t) {
            return DropdownMenuItem<String>(
              value: t.label,
              child: Text(t.label),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _onRoomTypeChanged(val);
            }
          },
        ),
      ],
    );
  }

  Widget _buildStep3Allocation(bool isDark) {
    final filtered = _filteredRooms;
    final selectedRoom = filtered.where((r) => r.id == _selectedRoomId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Room & Bed Allocation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Optionally assign room and bed immediately or admit to awaiting pool.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 14),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allocate Room & Bed Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: const Text('Turn off if student is placed on waiting list', style: TextStyle(fontSize: 11)),
          value: _autoAllocate,
          onChanged: (v) => setState(() => _autoAllocate = v),
        ),
        const SizedBox(height: 10),

        if (_autoAllocate) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Room *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Room Type: $_hostelType',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No rooms of type "$_hostelType" found in selected hostel. Please select another Room Type in Step 2 or create rooms in Rooms & Allocation.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: selectedRoom?.id,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: filtered.map((r) {
                final avail = (r.id == _selectedRoomId && !_isLoadingBeds)
                    ? _availableBedsInRoom.length
                    : r.availableBeds;
                final cap = r.capacity ?? 0;
                final feeStr = r.monthlyFee > 0 ? ' • ₹${r.monthlyFee.toInt()}/mo' : '';
                return DropdownMenuItem<String>(
                  value: r.id,
                  child: Text('Room ${r.roomNumber} (${r.roomType}) — $avail free of $cap beds$feeStr'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedRoomId = val;
                    _loadBedsForSelectedRoom(val);
                    _updateCalculatedFeeAndPayment();
                  });
                }
              },
            ),
            if (selectedRoom != null) ...[
              const SizedBox(height: 4),
              Text(
                'Room Base Fee: ₹${selectedRoom.monthlyFee.toInt()}/month (from Rooms & Allocation)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
              ),
            ],
          ],
          const SizedBox(height: 16),

          const Text('Bed Number / Identifier *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_isLoadingBeds)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  HostelSmoothSpinner(
                    size: 18,
                    strokeWidth: 2.2,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading vacant beds for this room...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else if (_availableBedsInRoom.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No vacant beds available in this room. Already booked/occupied beds are hidden. Please choose another room.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: _availableBedsInRoom.any((b) => b.id == _selectedBedId) ? _selectedBedId : _availableBedsInRoom.first.id,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'Select an available bed',
              ),
              items: _availableBedsInRoom.map((b) {
                final bedLabel = b.bedCode.isNotEmpty ? b.bedCode : 'Bed ${b.bedNumber ?? b.id}';
                final bedTypeSuffix = b.bedType.isNotEmpty ? ' (${b.bedType})' : '';
                return DropdownMenuItem<String>(
                  value: b.id,
                  child: Text('$bedLabel$bedTypeSuffix — Vacant / Available'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final bed = _availableBedsInRoom.where((b) => b.id == val).firstOrNull;
                  setState(() {
                    _selectedBedId = val;
                    _bedCode = bed?.bedCode.isNotEmpty == true
                        ? bed!.bedCode
                        : (bed?.bedNumber ?? val);
                    _updateCalculatedFeeAndPayment();
                  });
                }
              },
            ),
        ],
      ],
    );
  }

  Widget _buildStep4Fees(bool isDark) {
    final plans = _feePlanLookups.isNotEmpty
        ? _feePlanLookups
        : const [
            HostelLookupItem(id: '1', code: 'MONTHLY', label: 'Monthly'),
            HostelLookupItem(id: '2', code: 'QUARTERLY', label: 'Quarterly'),
            HostelLookupItem(id: '3', code: 'BI_ANNUAL', label: 'Bi-Annual'),
            HostelLookupItem(id: '4', code: 'ANNUAL', label: 'Annual'),
          ];

    final statuses = _initialPaymentStatusLookups.isNotEmpty
        ? _initialPaymentStatusLookups
        : const [
            HostelLookupItem(id: '1', code: 'PAID', label: 'Paid (Deposit & First Month)'),
            HostelLookupItem(id: '2', code: 'PENDING', label: 'Pending Payment'),
            HostelLookupItem(id: '3', code: 'PARTIAL', label: 'Partial Advance Paid'),
            HostelLookupItem(id: '4', code: 'WAIVED', label: 'Waived / Concession'),
          ];

    final planLabels = plans.map((p) => p.label).toList();
    final selectedPlan = planLabels.contains(_feePlan) ? _feePlan : planLabels.first;

    final statusCodes = statuses.map((s) => s.code).toList();
    final selectedStatus = statusCodes.contains(_feeStatus) ? _feeStatus : statusCodes.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fee Plan & Security Deposit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),

        // Fee Billing Plan (Dynamically loaded from DB lookups with clean names only)
        const Text('Fee Billing Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        AppSearchableDropdownFormField<String>.fromMenuItems(
          initialValue: selectedPlan,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: plans.map((p) {
            return DropdownMenuItem<String>(
              value: p.label,
              child: Text(p.label),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _feePlan = val;
                _updateCalculatedFeeAndPayment();
              });
            }
          },
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_feePlan Fee (₹)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _monthlyFeeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) {
                      if (_feeStatus == 'PAID') {
                        final fee = double.tryParse(_monthlyFeeController.text) ?? 0.0;
                        final dep = double.tryParse(_depositController.text) ?? 0.0;
                        _initialPaymentAmountController.text = (fee + dep).toStringAsFixed(0);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Security Deposit (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _depositController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (_) {
                      if (_feeStatus == 'PAID') {
                        final fee = double.tryParse(_monthlyFeeController.text) ?? 0.0;
                        final dep = double.tryParse(_depositController.text) ?? 0.0;
                        _initialPaymentAmountController.text = (fee + dep).toStringAsFixed(0);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Initial Fee Payment Status (dynamic) & Initial Fee Paid Amount (new input field)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Initial Fee Payment Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  AppSearchableDropdownFormField<String>.fromMenuItems(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: statuses.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.code,
                        child: Text(s.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _feeStatus = val;
                          _updateCalculatedFeeAndPayment();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Initial Fee Paid Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _initialPaymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'e.g. 16000',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Emergency Contact
        const Text('Emergency Contact Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _emergencyContactController,
          decoration: InputDecoration(
            hintText: '+91 98765 43210 (Father)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Review(HostelState state, bool isDark) {
    final b = state.structureTree.firstWhere(
      (x) => x.id == _selectedHostelId,
      orElse: () => state.structureTree.isNotEmpty ? state.structureTree.first : HostelBuilding(id: '', code: '', name: 'Hostel', hostelName: 'Hostel'),
    );

    final statusLabel = _initialPaymentStatusLookups.where((s) => s.code == _feeStatus).firstOrNull?.label ?? _feeStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review Admission Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Please verify student admission and allocation details before saving.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Student Name', _selectedStudent?.fullName ?? '-'),
              _buildReviewRow('Class & Roll No', '${_selectedStudent?.className ?? '-'} | Roll: ${_selectedStudent?.rollNumber ?? '-'}'),
              _buildReviewRow('Hostel Building', b.name),
              _buildReviewRow('Admission Date', DateFormat('dd MMM yyyy').format(_admissionDate)),
              _buildReviewRow('Room Type', _hostelType),
              _buildReviewRow('Room & Bed', _autoAllocate
                  ? 'Room ${_availableRooms.where((r) => r.id == _selectedRoomId).map((r) => r.roomNumber).firstOrNull ?? '-'} (${_bedCode.isNotEmpty ? (_bedCode.startsWith('Bed') ? _bedCode : 'Bed $_bedCode') : '-'})'
                  : 'Awaiting Allocation'),
              _buildReviewRow('Fee Plan', _feePlan),
              _buildReviewRow('Plan Fee Amount', '₹${_monthlyFeeController.text}'),
              _buildReviewRow('Security Deposit', '₹${_depositController.text}'),
              _buildReviewRow('Fee Status', statusLabel),
              _buildReviewRow('Initial Paid Amount', '₹${_initialPaymentAmountController.text}'),
              _buildReviewRow('Emergency Contact', _emergencyContactController.text.isNotEmpty ? _emergencyContactController.text : '-'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
