import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_fonts.dart';
import '../../../../providers/auth_provider.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

// ============================================================================
// 1. APPLY LEAVE DIALOG WITH COMPACT RESPONSIVE CALENDAR & DEDUCTION ENGINE
// ============================================================================
class ApplyLeaveDialog extends ConsumerStatefulWidget {
  final AttendanceLeaveRequestModel? initialData;

  const ApplyLeaveDialog({super.key, this.initialData});

  @override
  ConsumerState<ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends ConsumerState<ApplyLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedApplicantId;
  String _leaveType = 'Casual Leave';
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _halfDayType = 'FULL_DAY'; // FULL_DAY, FIRST_HALF, SECOND_HALF
  final _reasonCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _attachmentCtrl = TextEditingController();
  
  // Real File Upload state
  String? _uploadedFileUrl;
  String? _uploadedFileName;
  int? _uploadedFileSize;
  int? get uploadedFileSize => _uploadedFileSize;
  bool _isUploadingFile = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(attendanceProvider).publicHolidays.isEmpty) {
        ref.read(attendanceProvider.notifier).fetchLeaveHolidays();
      }
    });
    if (widget.initialData != null) {
      _leaveType = widget.initialData!.leaveType;
      _startDate = DateTime(widget.initialData!.startDate.year, widget.initialData!.startDate.month, widget.initialData!.startDate.day);
      _endDate = DateTime(widget.initialData!.endDate.year, widget.initialData!.endDate.month, widget.initialData!.endDate.day);
      _halfDayType = widget.initialData!.halfDayType;
      _reasonCtrl.text = widget.initialData!.reason;
      _contactCtrl.text = widget.initialData!.contactNumber ?? '';
      _uploadedFileUrl = widget.initialData!.attachmentUrl;
      _attachmentCtrl.text = _uploadedFileUrl ?? '';
      if (_uploadedFileUrl != null && _uploadedFileUrl!.isNotEmpty) {
        _uploadedFileName = _uploadedFileUrl!.split('/').last.split('?').first;
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _contactCtrl.dispose();
    _attachmentCtrl.dispose();
    super.dispose();
  }

  /// Active leave requests for target applicant (Only pending and approved block dates; cancelled/rejected are ignored)
  List<AttendanceLeaveRequestModel> _getActiveLeaves(AttendanceState state) {
    final authState = ref.read(authProvider);
    final currentUserId = authState.userData?['id']?.toString() ??
        authState.userData?['user_id']?.toString() ??
        '';
    final targetId = (_selectedApplicantId != null && _selectedApplicantId!.isNotEmpty)
        ? _selectedApplicantId!
        : currentUserId;

    final list = state.leaveRequests.where((r) {
      final isTarget = targetId.isNotEmpty ? (r.applicantId == targetId) : true;
      final status = r.status.trim().toLowerCase();
      return isTarget && (status == 'pending' || status == 'approved');
    }).toList();

    // Sort so APPROVED requests always take precedence over PENDING
    list.sort((a, b) {
      final aApproved = a.status.trim().toLowerCase() == 'approved' ? 0 : 1;
      final bApproved = b.status.trim().toLowerCase() == 'approved' ? 0 : 1;
      return aApproved.compareTo(bApproved);
    });

    return list;
  }

  /// Find active leave request covering a specific date (APPROVED takes precedence over PENDING)
  AttendanceLeaveRequestModel? _getActiveLeaveForDate(DateTime day, List<AttendanceLeaveRequestModel> activeLeaves) {
    final clean = DateTime(day.year, day.month, day.day);
    AttendanceLeaveRequestModel? pendingMatch;
    for (final req in activeLeaves) {
      final s = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
      final e = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
      if (!clean.isBefore(s) && !clean.isAfter(e)) {
        if (req.status.trim().toLowerCase() == 'approved') {
          return req; // Immediate return for APPROVED
        }
        pendingMatch ??= req;
      }
    }
    return pendingMatch;
  }

  /// Find public holiday for a specific date
  HolidayItemModel? _getHolidayForDate(DateTime day, List<HolidayItemModel> holidays) {
    final clean = DateTime(day.year, day.month, day.day);
    for (final h in holidays) {
      final hs = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
      final he = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
      if (!clean.isBefore(hs) && !clean.isAfter(he)) {
        return h;
      }
    }
    return null;
  }

  /// Compute detailed breakdown of dates in range
  /// Compute detailed breakdown of dates in range
  ({
    int totalCalendarDays,
    List<AttendanceLeaveRequestModel> overlappingLeaves,
    int overlapDaysCount,
    int approvedOverlapDaysCount,
    int pendingOverlapDaysCount,
    List<HolidayItemModel> holidays,
    int holidayDaysCount,
    double netBillableDays,
  })
  _calculateRangeBreakdown(DateTime start, DateTime end, String halfDayType, List<AttendanceLeaveRequestModel> activeLeaves, List<HolidayItemModel> holidays) {
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day);
    if (cleanEnd.isBefore(cleanStart)) {
      return (
        totalCalendarDays: 0,
        overlappingLeaves: [],
        overlapDaysCount: 0,
        approvedOverlapDaysCount: 0,
        pendingOverlapDaysCount: 0,
        holidays: [],
        holidayDaysCount: 0,
        netBillableDays: 0.0,
      );
    }

    final totalDays = (cleanEnd.difference(cleanStart).inDays + 1);
    final matchingHolidays = <HolidayItemModel>[];
    final matchingLeaves = <AttendanceLeaveRequestModel>[];
    int overlapDaysCount = 0;
    int approvedOverlapDaysCount = 0;
    int pendingOverlapDaysCount = 0;
    int holidayDaysCount = 0;

    for (int i = 0; i < totalDays; i++) {
      final curDate = cleanStart.add(Duration(days: i));
      
      // Check Holiday
      final h = _getHolidayForDate(curDate, holidays);
      if (h != null) {
        holidayDaysCount++;
        if (!matchingHolidays.any((m) => m.id == h.id)) {
          matchingHolidays.add(h);
        }
        continue; // Holiday takes precedence for zero deduction
      }

      // Check Active Leave (Approved vs Pending)
      final l = _getActiveLeaveForDate(curDate, activeLeaves);
      if (l != null) {
        overlapDaysCount++;
        final st = l.status.trim().toLowerCase();
        if (st == 'approved') {
          approvedOverlapDaysCount++;
        } else {
          pendingOverlapDaysCount++;
        }
        if (!matchingLeaves.any((m) => m.id == l.id)) {
          matchingLeaves.add(l);
        }
      }
    }

    double netDays = 0.0;
    if (halfDayType != 'FULL_DAY') {
      netDays = (holidayDaysCount > 0 || overlapDaysCount > 0) ? 0.0 : 0.5;
    } else {
      final effective = totalDays - holidayDaysCount - overlapDaysCount;
      netDays = effective <= 0 ? 0.0 : effective.toDouble();
    }

    return (
      totalCalendarDays: totalDays,
      overlappingLeaves: matchingLeaves,
      overlapDaysCount: overlapDaysCount,
      approvedOverlapDaysCount: approvedOverlapDaysCount,
      pendingOverlapDaysCount: pendingOverlapDaysCount,
      holidays: matchingHolidays,
      holidayDaysCount: holidayDaysCount,
      netBillableDays: netDays,
    );
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _isUploadingFile = true;
            _uploadedFileName = file.name;
            _uploadedFileSize = file.size;
          });

          final notifier = ref.read(attendanceProvider.notifier);
          final res = await notifier.uploadLeaveDocument(file.bytes!, file.name);

          if (mounted) {
            setState(() {
              _isUploadingFile = false;
              if (res['success'] == true && res['data'] != null) {
                _uploadedFileUrl = res['data']['file_url'];
                _attachmentCtrl.text = _uploadedFileUrl!;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document uploaded successfully!'),
                    backgroundColor: Color(0xFF10B981),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['detail'] ?? 'Failed to upload document'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingFile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _removeUploadedFile() {
    setState(() {
      _uploadedFileUrl = null;
      _uploadedFileName = null;
      _uploadedFileSize = null;
      _attachmentCtrl.clear();
    });
  }

  /// Open Compact, Ultra-Responsive Color-Coded Interactive Calendar Modal (Instant 0ms Load)
  Future<void> _openInteractiveCalendar(BuildContext context, bool isDark) async {
    final state = ref.read(attendanceProvider);
    final activeLeaves = _getActiveLeaves(state);
    final holidays = state.publicHolidays;

    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;
    DateTime currentMonth = DateTime(tempStart.year, tempStart.month, 1);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final breakdown = _calculateRangeBreakdown(tempStart, tempEnd, _halfDayType, activeLeaves, holidays);
            final daysInMonth = DateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
            final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday; // 1 = Mon, 7 = Sun
            final totalGridCells = ((daysInMonth + firstWeekday - 1) <= 35) ? 35 : 42;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5), size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Select Leave Period',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Quick Presets Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('Today', () {
                              final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                              setModalState(() {
                                tempStart = now;
                                tempEnd = now;
                                currentMonth = DateTime(now.year, now.month, 1);
                              });
                            }, isDark),
                            const SizedBox(width: 6),
                            _buildPresetChip('Tomorrow', () {
                              final tom = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1);
                              setModalState(() {
                                tempStart = tom;
                                tempEnd = tom;
                                currentMonth = DateTime(tom.year, tom.month, 1);
                              });
                            }, isDark),
                            const SizedBox(width: 6),
                            _buildPresetChip('3 Days', () {
                              final s = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                              final e = s.add(const Duration(days: 2));
                              setModalState(() {
                                tempStart = s;
                                tempEnd = e;
                                currentMonth = DateTime(s.year, s.month, 1);
                              });
                            }, isDark),
                            const SizedBox(width: 6),
                            _buildPresetChip('5 Days (Work Week)', () {
                              final s = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                              final e = s.add(const Duration(days: 4));
                              setModalState(() {
                                tempStart = s;
                                tempEnd = e;
                                currentMonth = DateTime(s.year, s.month, 1);
                              });
                            }, isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Month Navigator Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                setModalState(() {
                                  currentMonth = DateTime(currentMonth.year, currentMonth.month - 1, 1);
                                });
                              },
                            ),
                            Text(
                              DateFormat('MMMM yyyy').format(currentMonth),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                setModalState(() {
                                  currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Weekdays Header
                      Row(
                        children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((w) => Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: w == 'Su' ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 6),

                      // Compact Calendar Grid (Never overflows!)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: totalGridCells,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 3,
                          crossAxisSpacing: 3,
                          childAspectRatio: 1.45,
                        ),
                        itemBuilder: (ctx, index) {
                          final dayOffset = index - (firstWeekday - 1);
                          if (dayOffset < 0 || dayOffset >= daysInMonth) {
                            return const SizedBox.shrink();
                          }
                          final dayNumber = dayOffset + 1;
                          final cellDate = DateTime(currentMonth.year, currentMonth.month, dayNumber);

                          final isSelectedStart = cellDate.year == tempStart.year && cellDate.month == tempStart.month && cellDate.day == tempStart.day;
                          final isSelectedEnd = cellDate.year == tempEnd.year && cellDate.month == tempEnd.month && cellDate.day == tempEnd.day;
                          final isInSelectedRange = !cellDate.isBefore(tempStart) && !cellDate.isAfter(tempEnd);

                          final activeLeave = _getActiveLeaveForDate(cellDate, activeLeaves);
                          final holiday = _getHolidayForDate(cellDate, holidays);

                          final isApproved = activeLeave != null && activeLeave.status.trim().toLowerCase() == 'approved';
                          final isPending = activeLeave != null && !isApproved;

                          Color bgColor = Colors.transparent;
                          Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
                          Border? border;

                          if (isSelectedStart || isSelectedEnd) {
                            bgColor = const Color(0xFF4338CA);
                            textColor = Colors.white;
                          } else if (isInSelectedRange) {
                            bgColor = const Color(0xFF4F46E5).withValues(alpha: 0.85);
                            textColor = Colors.white;
                          } else if (holiday != null) {
                            // Emerald Green for Holiday
                            bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15);
                            textColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
                            border = Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5));
                          } else if (isApproved) {
                            // Cyan / Sky Blue for Approved Leave
                            bgColor = const Color(0xFF0284C7).withValues(alpha: isDark ? 0.25 : 0.15);
                            textColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
                            border = Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5));
                          } else if (isPending) {
                            // Amber / Orange for Pending Leave
                            bgColor = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15);
                            textColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
                            border = Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5));
                          }

                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                if (cellDate.isBefore(tempStart) || (!cellDate.isAfter(tempEnd) && tempStart != tempEnd)) {
                                  tempStart = cellDate;
                                  tempEnd = cellDate;
                                } else {
                                  tempEnd = cellDate;
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(6),
                                border: border,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: (isInSelectedRange || holiday != null || activeLeave != null) ? FontWeight.w800 : FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                  if (holiday != null && !isInSelectedRange)
                                    Positioned(
                                      bottom: 2,
                                      child: Container(
                                        width: 3.5,
                                        height: 3.5,
                                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                      ),
                                    )
                                  else if (isApproved && !isInSelectedRange)
                                    Positioned(
                                      bottom: 2,
                                      child: Container(
                                        width: 3.5,
                                        height: 3.5,
                                        decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                                      ),
                                    )
                                  else if (isPending && !isInSelectedRange)
                                    Positioned(
                                      bottom: 2,
                                      child: Container(
                                        width: 3.5,
                                        height: 3.5,
                                        decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Dynamic Legend Bar with Live Counts in Range & Month
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildLegendDot(const Color(0xFF4F46E5), 'Selected (${breakdown.totalCalendarDays}d)', isDark),
                              const SizedBox(width: 8),
                              _buildLegendDot(const Color(0xFF0284C7), 'Approved (${breakdown.approvedOverlapDaysCount}d excluded)', isDark),
                              const SizedBox(width: 8),
                              _buildLegendDot(const Color(0xFFF59E0B), 'Pending (${breakdown.pendingOverlapDaysCount}d excluded)', isDark),
                              const SizedBox(width: 8),
                              _buildLegendDot(const Color(0xFF10B981), 'Holiday (${breakdown.holidayDaysCount}d excluded)', isDark),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // High-Density Live Breakdown Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: breakdown.netBillableDays > 0
                              ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: breakdown.netBillableDays > 0
                                ? const Color(0xFF4F46E5).withValues(alpha: 0.25)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              breakdown.netBillableDays > 0 ? Icons.check_circle_outline : Icons.info_outline,
                              size: 16,
                              color: breakdown.netBillableDays > 0 ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${DateFormat('dd MMM').format(tempStart)} – ${DateFormat('dd MMM yyyy').format(tempEnd)} (${breakdown.totalCalendarDays} Total Days)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    breakdown.netBillableDays > 0
                                        ? '✨ Net Billable: ${breakdown.netBillableDays.toStringAsFixed(1)}d (${breakdown.approvedOverlapDaysCount > 0 ? '${breakdown.approvedOverlapDaysCount}d approved, ' : ''}${breakdown.pendingOverlapDaysCount > 0 ? '${breakdown.pendingOverlapDaysCount}d pending, ' : ''}${breakdown.holidayDaysCount}d holiday excluded)'
                                        : 'ℹ️ All ${breakdown.totalCalendarDays} day(s) already covered (${breakdown.approvedOverlapDaysCount > 0 ? '${breakdown.approvedOverlapDaysCount}d approved' : ''}${breakdown.pendingOverlapDaysCount > 0 ? '${breakdown.approvedOverlapDaysCount > 0 ? ' + ' : ''}${breakdown.pendingOverlapDaysCount}d pending' : ''}${breakdown.holidayDaysCount > 0 ? '${breakdown.overlapDaysCount > 0 ? ' + ' : ''}${breakdown.holidayDaysCount}d holiday' : ''}) • 0 new days to deduct',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: breakdown.netBillableDays > 0 ? const Color(0xFF4F46E5) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Modal Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text('Cancel', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _startDate = tempStart;
                                _endDate = tempEnd;
                              });
                              Navigator.of(ctx).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 0,
                            ),
                            child: const Text('Confirm Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be earlier than start date'), backgroundColor: Colors.red),
      );
      return;
    }

    final state = ref.watch(attendanceProvider);
    final activeLeaves = _getActiveLeaves(state);
    final breakdown = _calculateRangeBreakdown(_startDate, _endDate, _halfDayType, activeLeaves, state.publicHolidays);

    if (breakdown.netBillableDays <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All selected days are already covered by active leaves or official public holidays. No new leave days will be deducted.'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Dynamic Balance Matching (100% synchronized with Right Sidebar & Grid)
    double availableBalance = 12.0;
    if (_selectedApplicantId != null && _selectedApplicantId!.isNotEmpty) {
      final row = state.leaveBalances.cast<LeaveBalanceRowModel?>().firstWhere(
        (b) => b?.userId == _selectedApplicantId && (b?.leaveTypeName.toLowerCase() == _leaveType.toLowerCase() || b?.leaveTypeCode.toLowerCase() == _leaveType.toLowerCase()),
        orElse: () => null,
      );
      if (row != null) availableBalance = row.availableDays;
    } else {
      final summary = state.leaveDashboard.balanceSummary.cast<LeaveBalanceSummaryItemModel?>().firstWhere(
        (b) => b?.leaveTypeName.toLowerCase() == _leaveType.toLowerCase() || b?.leaveTypeCode.toLowerCase() == _leaveType.toLowerCase(),
        orElse: () => null,
      );
      if (summary != null) availableBalance = summary.availableDays;
    }

    if (breakdown.netBillableDays > availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot submit: Requested net duration (${breakdown.netBillableDays.toStringAsFixed(1)} days) exceeds remaining balance (${availableBalance.toStringAsFixed(1)} days) for $_leaveType.'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Policy conditional rules
    final policy = state.leaveTypes.cast<LeaveTypeModel?>().firstWhere(
      (t) => t?.name.toLowerCase() == _leaveType.toLowerCase() || t?.code.toLowerCase() == _leaveType.toLowerCase(),
      orElse: () => null,
    );

    final bool isDocRequired = (policy?.docRequired ?? false) && (breakdown.netBillableDays > (policy?.docRequiredAfterDays ?? 0));
    final effectiveAttachment = (_uploadedFileUrl != null && _uploadedFileUrl!.isNotEmpty)
        ? _uploadedFileUrl
        : (_attachmentCtrl.text.trim().isNotEmpty ? _attachmentCtrl.text.trim() : null);

    if (isDocRequired && (effectiveAttachment == null || effectiveAttachment.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A supporting document / medical certificate is required for $_leaveType exceeding ${policy?.docRequiredAfterDays ?? 0} days.'),
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.applyLeave(
      applicantId: _selectedApplicantId,
      leaveType: _leaveType,
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      reason: _reasonCtrl.text.trim(),
      halfDayType: _halfDayType,
      contactNumber: _contactCtrl.text.trim().isNotEmpty ? _contactCtrl.text.trim() : null,
      attachmentUrl: effectiveAttachment,
      billableDays: breakdown.netBillableDays,
      daysCount: breakdown.netBillableDays,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave application submitted successfully! (${breakdown.netBillableDays.toStringAsFixed(1)} net days booked)'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter leave types dynamically based on the selected applicant's role from app_roles
    final authState = ref.watch(authProvider);
    String applicantRole = authState.userData?['role']?.toString().toLowerCase() ?? '';
    if (applicantRole.isEmpty && state.activeRoles.isNotEmpty) {
      applicantRole = state.activeRoles.first.name.toLowerCase();
    }

    if (_selectedApplicantId != null && _selectedApplicantId!.isNotEmpty) {
      final emp = state.employeeLeaveBalances.cast<EmployeeLeaveBalanceModel?>().firstWhere(
        (e) => e?.userId == _selectedApplicantId,
        orElse: () => null,
      );
      if (emp != null && emp.role.isNotEmpty) {
        applicantRole = emp.role.toLowerCase();
      }
    }

    final applicableLeaveTypeModels = state.leaveTypes.where((t) {
      if (t.applicableRoles.isEmpty || t.applicableRoles.contains('all')) {
        return true;
      }
      if (applicantRole.isEmpty) return true;
      return t.applicableRoles.map((r) => r.toLowerCase()).contains(applicantRole);
    }).toList();

    final leaveTypes = applicableLeaveTypeModels.isNotEmpty
        ? applicableLeaveTypeModels.map((t) => t.name).toList()
        : state.leaveTypes.map((t) => t.name).toList();

    if (!leaveTypes.contains(_leaveType) && leaveTypes.isNotEmpty) {
      _leaveType = leaveTypes.first;
    }

    // 1. Dynamic Balance Matching (100% match with Right Sidebar Summary)
    double availableBalance = 12.0;
    double allocatedQuota = 12.0;
    double usedDays = 0.0;
    double pendingDays = 0.0;

    if (_selectedApplicantId != null && _selectedApplicantId!.isNotEmpty) {
      final row = state.leaveBalances.cast<LeaveBalanceRowModel?>().firstWhere(
        (b) => b?.userId == _selectedApplicantId && (b?.leaveTypeName.toLowerCase() == _leaveType.toLowerCase() || b?.leaveTypeCode.toLowerCase() == _leaveType.toLowerCase()),
        orElse: () => null,
      );
      if (row != null) {
        availableBalance = row.availableDays;
        allocatedQuota = row.allocatedDays;
        usedDays = row.usedDays;
        pendingDays = row.pendingDays;
      }
    } else {
      final summary = state.leaveDashboard.balanceSummary.cast<LeaveBalanceSummaryItemModel?>().firstWhere(
        (b) => b?.leaveTypeName.toLowerCase() == _leaveType.toLowerCase() || b?.leaveTypeCode.toLowerCase() == _leaveType.toLowerCase(),
        orElse: () => null,
      );
      if (summary != null) {
        availableBalance = summary.availableDays;
        allocatedQuota = summary.allocatedDays;
        usedDays = summary.usedDays;
        pendingDays = summary.pendingDays;
      }
    }

    // 2. Active Leaves & Detailed Range Breakdown
    final activeLeaves = _getActiveLeaves(state);
    final breakdown = _calculateRangeBreakdown(_startDate, _endDate, _halfDayType, activeLeaves, state.publicHolidays);

    // 3. Policy lookup
    final policy = state.leaveTypes.cast<LeaveTypeModel?>().firstWhere(
      (t) => t?.name.toLowerCase() == _leaveType.toLowerCase() || t?.code.toLowerCase() == _leaveType.toLowerCase(),
      orElse: () => null,
    );

    final bool isDocRequired = (policy?.docRequired ?? false) && (breakdown.netBillableDays > (policy?.docRequiredAfterDays ?? 0));
    final bool isExceedingBalance = breakdown.netBillableDays > availableBalance;
    final bool isZeroDaysDeduction = breakdown.netBillableDays <= 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.beach_access_rounded, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apply for Leave',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Smart calendar with automatic holiday & overlap deductions',
                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
                const Divider(height: 18),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Employee / Applicant Selector
                        if (state.staffRoster.isNotEmpty) ...[
                          Text('Applicant / Employee', style: _labelStyle(isDark)),
                          const SizedBox(height: 5),
                          DropdownButtonFormField<String>(
                            value: _selectedApplicantId,
                            hint: Text('Apply for Self (Current User)', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black45)),
                            isExpanded: true,
                            decoration: _inputDecoration(isDark, prefixIcon: Icons.person_outline),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text('Current Logged-in User', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              ),
                              ...state.staffRoster.map((s) => DropdownMenuItem<String>(
                                value: s.employeeId,
                                child: Text('${s.fullName} (${s.employeeCode}) - ${s.department}', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              )),
                            ],
                            onChanged: (v) => setState(() => _selectedApplicantId = v),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Leave Type & Duration Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Leave Type *', style: _labelStyle(isDark)),
                                  const SizedBox(height: 5),
                                  DropdownButtonFormField<String>(
                                    value: leaveTypes.contains(_leaveType) ? _leaveType : leaveTypes.first,
                                    decoration: _inputDecoration(isDark, prefixIcon: Icons.category_outlined),
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    items: leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _leaveType = v;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Duration Type', style: _labelStyle(isDark)),
                                  const SizedBox(height: 5),
                                  DropdownButtonFormField<String>(
                                    value: _halfDayType,
                                    decoration: _inputDecoration(isDark, prefixIcon: Icons.timelapse_outlined),
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    items: [
                                      const DropdownMenuItem(value: 'FULL_DAY', child: Text('Full Day', style: TextStyle(fontSize: 12.5))),
                                      if (policy?.allowHalfDay ?? true) ...[
                                        const DropdownMenuItem(value: 'FIRST_HALF', child: Text('Half Day (Morning)', style: TextStyle(fontSize: 12.5))),
                                        const DropdownMenuItem(value: 'SECOND_HALF', child: Text('Half Day (Afternoon)', style: TextStyle(fontSize: 12.5))),
                                      ],
                                    ],
                                    onChanged: (v) => setState(() => _halfDayType = v ?? 'FULL_DAY'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // DYNAMIC REMAINING LEAVE BALANCE INDICATOR CARD (100% matched with Sidebar & Grid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isExceedingBalance
                                ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExceedingBalance
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                  : const Color(0xFF10B981).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isExceedingBalance ? Icons.warning_amber_rounded : Icons.account_balance_wallet_outlined,
                                size: 18,
                                color: isExceedingBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$_leaveType Quota & Balance',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isExceedingBalance ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Text(
                                          '${availableBalance.toStringAsFixed(1)} / ${allocatedQuota.toStringAsFixed(0)} Days Left',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isExceedingBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    if (isExceedingBalance)
                                      Text(
                                        '⚠️ Requested net duration (${breakdown.netBillableDays.toStringAsFixed(1)} days) exceeds remaining balance (${availableBalance.toStringAsFixed(1)} days).',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                                      )
                                    else
                                      Text(
                                        'Used: ${usedDays.toStringAsFixed(1)}d • Pending: ${pendingDays.toStringAsFixed(1)}d • Balance after approval: ${(availableBalance - breakdown.netBillableDays).clamp(0, 999).toStringAsFixed(1)}d',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date Range Pickers (Clicking opens Compact Interactive Calendar)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From Date *', style: _labelStyle(isDark)),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () => _openInteractiveCalendar(context, isDark),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: _boxDecoration(isDark),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 15, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 8),
                                          Text(DateFormat('dd MMM yyyy').format(_startDate), style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A))),
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
                                  Text('To Date *', style: _labelStyle(isDark)),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () => _openInteractiveCalendar(context, isDark),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: _boxDecoration(isDark),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.event, size: 15, color: Color(0xFF4F46E5)),
                                          const SizedBox(width: 8),
                                          Text(DateFormat('dd MMM yyyy').format(_endDate), style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // DETAILED DURATION & NON-DEDUCTIBLE BREAKDOWN CARD
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 15, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Leave Duration Breakdown',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () => _openInteractiveCalendar(context, isDark),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.calendar_month, size: 13, color: Color(0xFF4F46E5)),
                                        SizedBox(width: 4),
                                        Text('Change Dates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Selected Period: ${breakdown.totalCalendarDays} Calendar Days',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              ),
                              if (breakdown.approvedOverlapDaysCount > 0) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.verified_outlined, size: 13, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '➖ ${breakdown.approvedOverlapDaysCount} Day(s) Approved Leave: ${breakdown.overlappingLeaves.where((l) => l.status.trim().toLowerCase() == 'approved').map((l) => '${l.requestCode} (${l.leaveType})').join(', ')} (0 deduction)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (breakdown.pendingOverlapDaysCount > 0) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.hourglass_top_outlined, size: 13, color: Color(0xFFD97706)),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '➖ ${breakdown.pendingOverlapDaysCount} Day(s) Pending Leave: ${breakdown.overlappingLeaves.where((l) => l.status.trim().toLowerCase() != 'approved').map((l) => '${l.requestCode} (${l.leaveType})').join(', ')} (0 duplicate deduction)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (breakdown.holidayDaysCount > 0) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.celebration_outlined, size: 13, color: Color(0xFF059669)),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        '➖ ${breakdown.holidayDaysCount} Day(s) Holiday: ${breakdown.holidays.map((h) => '${h.title} (${DateFormat('dd MMM').format(h.startDate)})').join(', ')} (0 deduction)',
                                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const Divider(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('✨ Net Leave to Apply & Deduct:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                  Text(
                                    '${breakdown.netBillableDays.toStringAsFixed(1)} ${breakdown.netBillableDays == 1.0 ? 'Day' : 'Days'}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // POLICY DOCUMENT MANDATORY WARNING
                        if (isDocRequired) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_late_outlined, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Supporting Medical Certificate / Proof is MANDATORY for $_leaveType exceeding ${policy?.docRequiredAfterDays ?? 0} days.',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Reason for Leave
                        Text('Reason / Justification *', style: _labelStyle(isDark)),
                        const SizedBox(height: 5),
                        TextFormField(
                          controller: _reasonCtrl,
                          maxLines: 2,
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Please enter a valid reason (min 3 chars)' : null,
                          decoration: _inputDecoration(isDark, hintText: 'Enter specific reason for taking leave...'),
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),

                        // Emergency Contact & Real Document Attachment
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Emergency Contact', style: _labelStyle(isDark)),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: _contactCtrl,
                                    decoration: _inputDecoration(isDark, prefixIcon: Icons.phone_outlined, hintText: '+91 9876543210'),
                                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isDocRequired ? 'Supporting Document *' : 'Supporting Document',
                                        style: _labelStyle(isDark),
                                      ),
                                      if (isDocRequired)
                                        const Text(' (Required)', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  
                                  // Real Document Upload UI Component
                                  if (_uploadedFileUrl != null && _uploadedFileUrl!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 15, color: Color(0xFF10B981)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _uploadedFileName ?? 'Document Attached',
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (_uploadedFileSize != null)
                                                  Text(
                                                    '${(_uploadedFileSize! / 1024).toStringAsFixed(1)} KB',
                                                    style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 15, color: Color(0xFFEF4444)),
                                            onPressed: _removeUploadedFile,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (_isUploadingFile)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                          SizedBox(width: 6),
                                          Text('Uploading...', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    )
                                  else
                                    OutlinedButton.icon(
                                      onPressed: _pickAndUploadFile,
                                      icon: const Icon(Icons.cloud_upload_outlined, size: 15),
                                      label: Text(
                                        isDocRequired ? 'Upload Required File' : 'Upload Document',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDocRequired ? const Color(0xFFD97706) : null),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        side: BorderSide(
                                          color: isDocRequired ? const Color(0xFFD97706) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                          width: isDocRequired ? 1.5 : 1.0,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 18),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black54)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: (_isSubmitting || isExceedingBalance || isZeroDaysDeduction) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (isExceedingBalance || isZeroDaysDeduction)
                            ? Colors.grey
                            : const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              isZeroDaysDeduction
                                  ? 'Already Covered (0 New Days)'
                                  : (isExceedingBalance
                                      ? 'Balance Exceeded'
                                      : 'Submit Application (${breakdown.netBillableDays.toStringAsFixed(1)}d)'),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _labelStyle(bool isDark) => TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
  );

  InputDecoration _inputDecoration(bool isDark, {IconData? prefixIcon, String? hintText}) => InputDecoration(
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 16, color: const Color(0xFF64748B)) : null,
    hintText: hintText,
    hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
    filled: true,
    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
  );

  BoxDecoration _boxDecoration(bool isDark) => BoxDecoration(
    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
  );
}

// 2. PERMISSION (SHORT LEAVE) REQUEST DIALOG
// ============================================================================
class PermissionRequestDialog extends ConsumerStatefulWidget {
  const PermissionRequestDialog({super.key});

  @override
  ConsumerState<PermissionRequestDialog> createState() => _PermissionRequestDialogState();
}

class _PermissionRequestDialogState extends ConsumerState<PermissionRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedApplicantId;
  String _permissionType = 'SHORT_PERMISSION';
  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _durationHours {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    final diff = endMin - startMin;
    return diff > 0 ? diff / 60.0 : 1.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
    final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.applyPermissionRequest(
      applicantId: _selectedApplicantId,
      permissionType: _permissionType,
      date: DateFormat('yyyy-MM-dd').format(_date),
      startTime: startStr,
      endTime: endStr,
      durationHours: _durationHours,
      reason: _reasonCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission request submitted successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFF06B6D4), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission / Short Leave Request',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Request early departure, late arrival, or official hours away',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Staff Selector
              if (state.staffRoster.isNotEmpty) ...[
                Text('Applicant / Employee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedApplicantId,
                  hint: const Text('Apply for Self (Current User)', style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Current Logged-in User', style: TextStyle(fontSize: 13))),
                    ...state.staffRoster.map((s) => DropdownMenuItem<String>(
                      value: s.employeeId,
                      child: Text('${s.fullName} (${s.employeeCode})', style: const TextStyle(fontSize: 13)),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedApplicantId = v),
                ),
                const SizedBox(height: 14),
              ],

              // Permission Type
              Text('Permission Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _permissionType,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: const [
                  DropdownMenuItem(value: 'LATE_ARRIVAL', child: Text('Late Arrival (1-2 Hours)')),
                  DropdownMenuItem(value: 'EARLY_DEPARTURE', child: Text('Early Departure (1-2 Hours)')),
                  DropdownMenuItem(value: 'SHORT_PERMISSION', child: Text('Short Permission (During Day)')),
                  DropdownMenuItem(value: 'MEDICAL', child: Text('Medical / Dental Appointment')),
                  DropdownMenuItem(value: 'OFFICIAL', child: Text('Official School Work')),
                  DropdownMenuItem(value: 'PERSONAL', child: Text('Personal / Emergency')),
                ],
                onChanged: (v) => setState(() => _permissionType = v ?? 'SHORT_PERMISSION'),
              ),
              const SizedBox(height: 14),

              // Date & Time Range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 60)),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 8),
                                Text(DateFormat('dd MMM yyyy').format(_date), style: const TextStyle(fontSize: 13)),
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
                        Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _startTime);
                            if (picked != null) setState(() => _startTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 8),
                                Text(_startTime.format(context), style: const TextStyle(fontSize: 13)),
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
                        Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(context: context, initialTime: _endTime);
                            if (picked != null) setState(() => _endTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: Color(0xFF06B6D4)),
                                const SizedBox(width: 8),
                                Text(_endTime.format(context), style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Calculated Duration Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Duration: ${_durationHours.toStringAsFixed(1)} Hours',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0891B2)),
                ),
              ),
              const SizedBox(height: 14),

              // Reason
              Text('Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter reason' : null,
                decoration: InputDecoration(
                  hintText: 'Brief explanation for short permission...',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w700)),
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

// ============================================================================
// 3. LEAVE DETAIL DRAWER / INSPECTOR
// ============================================================================
class LeaveDetailDrawer extends ConsumerStatefulWidget {
  final AttendanceLeaveRequestModel request;

  const LeaveDetailDrawer({super.key, required this.request});

  @override
  ConsumerState<LeaveDetailDrawer> createState() => _LeaveDetailDrawerState();
}

class _LeaveDetailDrawerState extends ConsumerState<LeaveDetailDrawer> {
  final _remarksCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action == "APPROVE" ? "Approve" : action == "REJECT" ? "Reject" : "Cancel"} Leave Request'),
        content: Text('Are you sure you want to $action this leave request for ${widget.request.applicantName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'APPROVE' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'APPROVE' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.handleLeaveAction(
      widget.request.id,
      action,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave request $action successfully!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: 480,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: req.leaveTypeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment_outlined, color: req.leaveTypeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request: ${req.requestCode.isNotEmpty ? req.requestCode : req.id.substring(0, 8)}',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Applied on ${DateFormat('dd MMM yyyy, hh:mm a').format(req.appliedAt)}',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            backgroundImage: (req.avatarUrl != null && req.avatarUrl!.isNotEmpty) ? NetworkImage(req.avatarUrl!) : null,
                            child: (req.avatarUrl == null || req.avatarUrl!.isEmpty)
                                ? Text(req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : 'A', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)))
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.applicantName,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${req.employeeCode.isNotEmpty ? req.employeeCode : 'EMP'} • ${req.department} • ${req.applicantRole.toUpperCase()}',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(req.status, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Leave Information Grid
                    Text('Leave Specifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    _buildInfoRow('Leave Type', req.leaveType, isDark, highlightColor: req.leaveTypeColor),
                    _buildInfoRow('From Date', DateFormat('dd MMM yyyy (EEEE)').format(req.startDate), isDark),
                    _buildInfoRow('To Date', DateFormat('dd MMM yyyy (EEEE)').format(req.endDate), isDark),
                    _buildInfoRow('Duration', '${req.daysCount} Days (${req.halfDayType.replaceAll('_', ' ')})', isDark),
                    if (req.contactNumber != null && req.contactNumber!.isNotEmpty)
                      _buildInfoRow('Contact', req.contactNumber!, isDark),
                    const SizedBox(height: 16),

                    // Reason Box
                    Text('Reason / Justification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        req.reason,
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Attached Supporting Document (if available)
                    if (req.attachmentUrl != null && req.attachmentUrl!.isNotEmpty) ...[
                      Text('Supporting Document / Certificate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.picture_as_pdf, color: Color(0xFF4F46E5), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req.attachmentUrl!.split('/').last.split('?').first,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Text('Attached Document Proof', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => launchUrl(Uri.parse(req.attachmentUrl!)),
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text('View / Download', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Multi-Stage Approval Timeline
                    Text('Approval Workflow Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    _buildTimelineStage(
                      stageNumber: 1,
                      title: 'Application Submitted',
                      subtitle: 'By ${req.applicantName} on ${DateFormat('dd MMM yyyy').format(req.appliedAt)}',
                      isCompleted: true,
                      isDark: isDark,
                    ),
                    _buildTimelineStage(
                      stageNumber: 2,
                      title: 'Reporting Manager Review',
                      subtitle: req.status.toUpperCase() == 'APPROVED'
                          ? 'Approved by ${req.approvedByName ?? "Manager"}'
                          : (req.status.toUpperCase() == 'REJECTED' ? 'Rejected by ${req.approvedByName ?? "Manager"}' : 'Pending Review'),
                      isCompleted: req.status.toUpperCase() != 'PENDING',
                      isRejected: req.status.toUpperCase() == 'REJECTED',
                      isDark: isDark,
                    ),
                    _buildTimelineStage(
                      stageNumber: 3,
                      title: 'Attendance Auto-Synchronization',
                      subtitle: req.status.toUpperCase() == 'APPROVED'
                          ? 'Roster updated with status: On Leave (O)'
                          : 'Awaiting leave approval',
                      isCompleted: req.status.toUpperCase() == 'APPROVED',
                      isLast: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Remarks Input
                    if (req.status.toUpperCase() == 'PENDING') ...[
                      Text('Review Remarks / Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter approval or rejection remarks...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Bar (if Pending)
            if (req.status.toUpperCase() == 'PENDING')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleAction('REJECT'),
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleAction('APPROVE'),
                        icon: const Icon(Icons.check, size: 16, color: Colors.white),
                        label: const Text('Approve Leave', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
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

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStage({
    required int stageNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isRejected = false,
    bool isLast = false,
    required bool isDark,
  }) {
    final color = isRejected ? const Color(0xFFEF4444) : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                isRejected ? Icons.close : (isCompleted ? Icons.check : Icons.circle),
                size: 12,
                color: color,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: isCompleted ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        break;
      case 'PENDING':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
      case 'REJECTED':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

// ============================================================================
// 3B. PERMISSION / SHORT LEAVE DETAIL DRAWER (Reusing Design System)
// ============================================================================
class PermissionDetailDrawer extends ConsumerStatefulWidget {
  final PermissionRequestModel permission;

  const PermissionDetailDrawer({super.key, required this.permission});

  @override
  ConsumerState<PermissionDetailDrawer> createState() => _PermissionDetailDrawerState();
}

class _PermissionDetailDrawerState extends ConsumerState<PermissionDetailDrawer> {
  final _remarksCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action == "APPROVE" ? "Approve" : action == "REJECT" ? "Reject" : "Cancel"} Permission Request'),
        content: Text('Are you sure you want to $action this permission request for ${widget.permission.applicantName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'APPROVE' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(action == 'APPROVE' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.handlePermissionAction(
      permissionId: widget.permission.id,
      action: action,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permission request $action successfully!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    }
  }

  String _cleanTime(String t) {
    if (t.isEmpty) return '--:--';
    final parts = t.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final perm = widget.permission;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const permColor = Color(0xFF06B6D4);

    return Drawer(
      width: 480,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: permColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: permColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission: ${perm.requestCode.isNotEmpty ? perm.requestCode : (perm.id.length > 8 ? perm.id.substring(0, 8) : perm.id)}',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Requested on ${DateFormat('dd MMM yyyy, hh:mm a').format(perm.createdAt)}',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: permColor.withValues(alpha: 0.2),
                            backgroundImage: (perm.avatarUrl != null && perm.avatarUrl!.isNotEmpty) ? NetworkImage(perm.avatarUrl!) : null,
                            child: (perm.avatarUrl == null || perm.avatarUrl!.isEmpty)
                                ? Text(perm.applicantName.isNotEmpty ? perm.applicantName[0].toUpperCase() : 'A', style: const TextStyle(fontWeight: FontWeight.w800, color: permColor))
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  perm.applicantName,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${perm.employeeCode.isNotEmpty ? perm.employeeCode : 'EMP'} • ${perm.department} • ${perm.applicantRole.toUpperCase()}',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(perm.status, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Permission Specifications Grid
                    Text('Permission Specifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    _buildInfoRow('Permission Type', perm.permissionType.replaceAll('_', ' '), isDark, highlightColor: permColor),
                    _buildInfoRow('Date', DateFormat('dd MMM yyyy (EEEE)').format(perm.permissionDate), isDark),
                    _buildInfoRow('Time Range', '${_cleanTime(perm.startTime)} - ${_cleanTime(perm.endTime)}', isDark),
                    _buildInfoRow('Duration', '${perm.durationHours} Hours', isDark),
                    if (perm.approvedByName != null && perm.approvedByName!.isNotEmpty)
                      _buildInfoRow('Reviewed By', perm.approvedByName!, isDark),
                    const SizedBox(height: 16),

                    // Reason Box
                    Text('Reason / Justification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        perm.reason.isNotEmpty ? perm.reason : 'No reason provided',
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Remarks or Rejection Reason if available
                    if (perm.rejectionReason != null && perm.rejectionReason!.isNotEmpty) ...[
                      Text('Rejection Reason', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFEF4444))),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          perm.rejectionReason!,
                          style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFFEF4444)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Multi-Stage Approval Timeline
                    Text('Approval Workflow Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    _buildTimelineStage(
                      stageNumber: 1,
                      title: 'Permission Requested',
                      subtitle: 'By ${perm.applicantName} on ${DateFormat('dd MMM yyyy').format(perm.createdAt)}',
                      isCompleted: true,
                      isDark: isDark,
                    ),
                    _buildTimelineStage(
                      stageNumber: 2,
                      title: 'Supervisor / Manager Review',
                      subtitle: perm.status.toUpperCase() == 'APPROVED'
                          ? 'Approved by ${perm.approvedByName ?? "Manager"}'
                          : (perm.status.toUpperCase() == 'REJECTED' ? 'Rejected by ${perm.approvedByName ?? "Manager"}' : 'Pending Review'),
                      isCompleted: perm.status.toUpperCase() != 'PENDING',
                      isRejected: perm.status.toUpperCase() == 'REJECTED',
                      isDark: isDark,
                    ),
                    _buildTimelineStage(
                      stageNumber: 3,
                      title: 'Attendance Auto-Synchronization',
                      subtitle: perm.status.toUpperCase() == 'APPROVED'
                          ? 'Permission pass issued & attendance adjusted'
                          : 'Awaiting permission approval',
                      isCompleted: perm.status.toUpperCase() == 'APPROVED',
                      isLast: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // Remarks Input (if Pending)
                    if (perm.status.toUpperCase() == 'PENDING') ...[
                      Text('Review Remarks / Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter approval or rejection remarks...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Bar (if Pending)
            if (perm.status.toUpperCase() == 'PENDING')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleAction('REJECT'),
                        icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _handleAction('APPROVE'),
                        icon: const Icon(Icons.check, size: 16, color: Colors.white),
                        label: const Text('Approve Permission', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
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

  Widget _buildInfoRow(String label, String value, bool isDark, {Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: highlightColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStage({
    required int stageNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    bool isRejected = false,
    bool isLast = false,
    required bool isDark,
  }) {
    final color = isRejected ? const Color(0xFFEF4444) : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                isRejected ? Icons.close : (isCompleted ? Icons.check : Icons.circle),
                size: 12,
                color: color,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 32, color: isCompleted ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    switch (status.toUpperCase()) {
      case 'APPROVED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        break;
      case 'PENDING':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFD97706);
        break;
      case 'REJECTED':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

// ============================================================================
// 4. BALANCE ADJUSTMENT DIALOG
// ============================================================================
class BalanceAdjustmentDialog extends ConsumerStatefulWidget {
  final LeaveBalanceRowModel balanceRow;

  const BalanceAdjustmentDialog({super.key, required this.balanceRow});

  @override
  ConsumerState<BalanceAdjustmentDialog> createState() => _BalanceAdjustmentDialogState();
}

class _BalanceAdjustmentDialogState extends ConsumerState<BalanceAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  String _adjustmentType = 'CREDIT'; // CREDIT or DEBIT
  final _daysCtrl = TextEditingController(text: '1.0');
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _daysCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final val = double.tryParse(_daysCtrl.text.trim()) ?? 0.0;
    if (val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter positive number of days'), backgroundColor: Colors.red),
      );
      return;
    }

    final adjustment = _adjustmentType == 'CREDIT' ? val : -val;

    setState(() => _isSubmitting = true);
    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.adjustLeaveBalance(
      userId: widget.balanceRow.userId,
      leaveTypeId: widget.balanceRow.leaveTypeId,
      adjustmentDays: adjustment,
      reason: _reasonCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave balance adjusted and audit logged!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.balanceRow;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adjust Leave Balance',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${row.fullName} (${row.employeeCode}) • ${row.leaveTypeName}',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const Divider(height: 24),

              // Current Balance Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Quota: ${row.allocatedDays} Days', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    Text('Available: ${row.availableDays} Days', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Credit vs Debit
              Text('Adjustment Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Credit (+)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                      value: 'CREDIT',
                      groupValue: _adjustmentType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _adjustmentType = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Debit (-)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                      value: 'DEBIT',
                      groupValue: _adjustmentType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) => setState(() => _adjustmentType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Days
              Text('Number of Days *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _daysCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter days' : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              // Reason
              Text('Reason / Justification * (Immutable Audit Log)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : const Color(0xFF475569))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 2,
                validator: (v) => (v == null || v.trim().length < 3) ? 'Mandatory justification required' : null,
                decoration: InputDecoration(
                  hintText: 'e.g. Compensatory off for weekend workshop',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Adjustment', style: TextStyle(fontWeight: FontWeight.w700)),
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

// ============================================================================
// 5. LEAVE TYPE & POLICY DIALOG
// ============================================================================
class LeaveTypeDialog extends ConsumerStatefulWidget {
  final LeaveTypeModel? initialData;

  const LeaveTypeDialog({super.key, this.initialData});

  @override
  ConsumerState<LeaveTypeDialog> createState() => _LeaveTypeDialogState();
}

class _LeaveTypeDialogState extends ConsumerState<LeaveTypeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _category = 'PAID';
  final _entitlementCtrl = TextEditingController(text: '12.0');
  bool _monthlyAccrual = false;
  bool _carryForwardAllowed = true;
  final _maxCarryForwardCtrl = TextEditingController(text: '5.0');
  bool _encashmentAllowed = false;
  bool _docRequired = false;
  final _docDaysCtrl = TextEditingController(text: '2.0');
  bool _allowHalfDay = true;
  bool _allRolesSelected = true;
  final Set<String> _selectedRoles = {};
  String _colorHex = '#4F46E5';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).fetchActiveRoles();
    });
    if (widget.initialData != null) {
      final t = widget.initialData!;
      _nameCtrl.text = t.name;
      _codeCtrl.text = t.code;
      _category = t.category;
      _entitlementCtrl.text = t.annualEntitlement.toString();
      _monthlyAccrual = t.monthlyAccrual;
      _carryForwardAllowed = t.carryForwardAllowed;
      _maxCarryForwardCtrl.text = t.maxCarryForward.toString();
      _encashmentAllowed = t.encashmentAllowed;
      _docRequired = t.docRequired;
      _docDaysCtrl.text = t.docRequiredAfterDays.toString();
      _allowHalfDay = t.allowHalfDay;
      final argb = t.color.toARGB32();
      _colorHex = '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      if (t.applicableRoles.isNotEmpty && !t.applicableRoles.contains('all')) {
        _allRolesSelected = false;
        _selectedRoles.addAll(t.applicableRoles.map((r) => r.toLowerCase()));
      } else {
        _allRolesSelected = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _entitlementCtrl.dispose();
    _maxCarryForwardCtrl.dispose();
    _docDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final List<String> applicableRolesPayload;
    if (_allRolesSelected || _selectedRoles.isEmpty) {
      applicableRolesPayload = ['all'];
    } else {
      applicableRolesPayload = _selectedRoles.toList();
    }

    final payload = {
      if (widget.initialData != null) 'id': widget.initialData!.id,
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'category': _category,
      'annual_entitlement': double.tryParse(_entitlementCtrl.text) ?? 12.0,
      'monthly_accrual': _monthlyAccrual,
      'carry_forward_allowed': _carryForwardAllowed,
      'max_carry_forward': double.tryParse(_maxCarryForwardCtrl.text) ?? 5.0,
      'encashment_allowed': _encashmentAllowed,
      'doc_required': _docRequired,
      'doc_required_after_days': double.tryParse(_docDaysCtrl.text) ?? 2.0,
      'allow_half_day': _allowHalfDay,
      'applicable_roles': applicableRolesPayload,
      'color_hex': _colorHex,
      'is_active': true,
    };

    final notifier = ref.read(attendanceProvider.notifier);
    final success = await notifier.saveLeaveType(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave type policy saved successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.policy_outlined, color: Color(0xFF8B5CF6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialData != null ? 'Edit Leave Policy' : 'Add New Leave Policy',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Configure annual quotas, carry-forward, and document rules',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name & Code
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Policy Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameCtrl,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                                  decoration: InputDecoration(hintText: 'e.g. Sabbatical Leave', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeCtrl,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter code' : null,
                                  decoration: InputDecoration(hintText: 'e.g. SAB', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Category & Quota
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _category,
                                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                  items: const [
                                    DropdownMenuItem(value: 'PAID', child: Text('Paid Leave')),
                                    DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid Leave')),
                                    DropdownMenuItem(value: 'SPECIAL', child: Text('Special Leave')),
                                  ],
                                  onChanged: (v) => setState(() => _category = v ?? 'PAID'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Annual Entitlement (Days)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _entitlementCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Applicable Roles Section (from app_roles)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Applicable Roles',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'All Roles',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Switch(
                                      value: _allRolesSelected,
                                      activeColor: const Color(0xFF8B5CF6),
                                      onChanged: (v) {
                                        setState(() {
                                          _allRolesSelected = v;
                                          if (v) {
                                            _selectedRoles.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              _allRolesSelected
                                  ? 'This leave policy is available to all users and roles across the institution.'
                                  : 'Select specific roles from app_roles eligible for this leave policy (${_selectedRoles.length} selected):',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            if (!_allRolesSelected) ...[
                              const SizedBox(height: 10),
                              Builder(
                                builder: (ctx) {
                                  final activeRoles = ref.watch(attendanceProvider).activeRoles;
                                  if (activeRoles.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Center(
                                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                    );
                                  }
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: activeRoles.map((role) {
                                      final roleKey = role.name.toLowerCase();
                                      final isSelected = _selectedRoles.contains(roleKey);
                                      return FilterChip(
                                        label: Text(role.displayName.isNotEmpty ? role.displayName : role.name),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedRoles.add(roleKey);
                                            } else {
                                              _selectedRoles.remove(roleKey);
                                            }
                                          });
                                        },
                                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                        checkmarkColor: const Color(0xFF8B5CF6),
                                        labelStyle: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFF8B5CF6)
                                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                        ),
                                        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF8B5CF6)
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Toggles: Half Day, Carry Forward, Encashment, Medical Certificate
                      SwitchListTile(
                        title: const Text('Allow Half-Day Applications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _allowHalfDay,
                        onChanged: (v) => setState(() => _allowHalfDay = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        title: const Text('Allow Carry-Forward to Next Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _carryForwardAllowed,
                        onChanged: (v) => setState(() => _carryForwardAllowed = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_carryForwardAllowed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: _maxCarryForwardCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Max Carry Forward Days', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                      SwitchListTile(
                        title: const Text('Require Medical / Proof Document', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _docRequired,
                        onChanged: (v) => setState(() => _docRequired = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_docRequired)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: _docDaysCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Document Required After Days', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Policy', style: TextStyle(fontWeight: FontWeight.w700)),
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


// ============================================================================
// 6. INTERACTIVE LEAVE CALENDAR VIEW DIALOG
// ============================================================================
class LeaveCalendarViewDialog extends ConsumerStatefulWidget {
  const LeaveCalendarViewDialog({super.key});

  @override
  ConsumerState<LeaveCalendarViewDialog> createState() => _LeaveCalendarViewDialogState();
}

class _LeaveCalendarViewDialogState extends ConsumerState<LeaveCalendarViewDialog> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requests = state.leaveRequests;

    // Filter requests active in the current month
    final monthStart = _currentMonth;
    final monthEnd = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // Days in month calculation
    final daysInMonth = monthEnd.day;
    final firstWeekday = monthStart.weekday % 7; // Sunday = 0

    // Selected date leaves
    final targetDate = _selectedDate ?? DateTime.now();
    final selectedLeaves = requests.where((r) {
      final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      final t = DateTime(targetDate.year, targetDate.month, targetDate.day);
      return !t.isBefore(s) && !t.isAfter(e);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 750),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Calendar & Timeline',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Visual overview of approved and pending employee leaves',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const Divider(height: 24),

            // Month Navigation Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _prevMonth,
                      tooltip: 'Previous Month',
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_currentMonth),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _nextMonth,
                      tooltip: 'Next Month',
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Calendar Days & Details Split
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left 60%: Calendar Grid
                  Expanded(
                    flex: 60,
                    child: Column(
                      children: [
                        // Weekday headers
                        Row(
                          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((d) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        // Days Grid
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.15,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                            itemCount: 42, // 6 weeks
                            itemBuilder: (ctx, idx) {
                              final dayNumber = idx - firstWeekday + 1;
                              final isValidDay = dayNumber >= 1 && dayNumber <= daysInMonth;
                              if (!isValidDay) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                );
                              }

                              final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                              final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
                              final isSelected = _selectedDate != null && date.year == _selectedDate!.year && date.month == _selectedDate!.month && date.day == _selectedDate!.day;

                              // Count leaves active on this day
                              final dayLeaves = requests.where((r) {
                                final s = DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
                                final e = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
                                return !date.isBefore(s) && !date.isAfter(e);
                              }).toList();

                              return InkWell(
                                onTap: () => setState(() => _selectedDate = date),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : (isToday ? const Color(0xFF4F46E5).withValues(alpha: 0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$dayNumber',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isToday ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (dayLeaves.isNotEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: dayLeaves.first.leaveTypeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${dayLeaves.length} on leave',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: dayLeaves.first.leaveTypeColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),
                  const VerticalDivider(),
                  const SizedBox(width: 16),

                  // Right 40%: Leaves on Selected Date
                  Expanded(
                    flex: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leaves on ${DateFormat("dd MMMM yyyy").format(targetDate)}',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        if (selectedLeaves.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available, size: 36, color: Color(0xFF10B981)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No employees on leave on this date.',
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: selectedLeaves.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final req = selectedLeaves[i];
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: req.leaveTypeColor.withValues(alpha: 0.15),
                                        child: Text(req.applicantName.isNotEmpty ? req.applicantName[0].toUpperCase() : 'A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: req.leaveTypeColor)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(req.applicantName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text('${req.department} • ${req.leaveType}', style: TextStyle(fontSize: 10.5, color: req.leaveTypeColor, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: req.status.toUpperCase() == 'APPROVED' ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          req.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: req.status.toUpperCase() == 'APPROVED' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
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
