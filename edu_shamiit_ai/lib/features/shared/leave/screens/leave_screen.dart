import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/leave_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

// ─── Leave type definitions ──────────────────────────────────────────────────

const _studentLeaveTypes = [
  'Sick Leave',
  'Casual Leave',
  'Family Event',
  'Urgent Work',
  'Sports Competition',
  'Others',
];

const _teacherLeaveTypes = [
  'Sick Leave',
  'Casual Leave',
  'Earned Leave',
  'Maternity Leave',
  'Paternity Leave',
  'Personal Leave',
  'Others',
];

String _leaveIcon(String type) {
  switch (type.toLowerCase()) {
    case 'sick leave':
      return '🤒';
    case 'casual leave':
      return '☀️';
    case 'family event':
      return '👨‍👩‍👧';
    case 'urgent work':
      return '⚡';
    case 'sports competition':
      return '🏅';
    case 'earned leave':
      return '🌴';
    case 'maternity leave':
      return '🤱';
    case 'paternity leave':
      return '👶';
    case 'personal leave':
      return '🙏';
    default:
      return '📋';
  }
}

// ─── Color constants ─────────────────────────────────────────────────────────

const _primaryStudent = Color(0xFF4F46E5);
const _primaryTeacher = Color(0xFF8B5CF6);
const _accentColor = Color(0xFF06B6D4);
const _bgColor = Color(0xFFF0F2FF);
const _cardColor = Colors.white;

Color _primaryFor(bool isTeacher) =>
    isTeacher ? _primaryTeacher : _primaryStudent;

// ─── Main screen ─────────────────────────────────────────────────────────────

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isStatsCollapsed = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    Future.microtask(
        () => ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isTeacher => ref.read(authProvider).role == UserRole.teacher;

  String get _dashboardRoute =>
      _isTeacher ? '/teacher/dashboard' : '/student/dashboard';

  List<String> get _leaveTypes =>
      _isTeacher ? _teacherLeaveTypes : _studentLeaveTypes;

  Color get _primary => _primaryFor(_isTeacher);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveProvider);
    final isTeacher = _isTeacher;
    final primary = _primary;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, Responsive.headerTopPadding(context), 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primary,
                    isTeacher ? const Color(0xFFA78BFA) : _accentColor,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Top row
                  Row(
                    children: [
                      _GlassBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => safeGoBack(context, _dashboardRoute),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Leave Management',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isTeacher ? 'Teacher Portal' : 'Student Portal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _GlassBtn(
                        icon: _isStatsCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        onTap: () => setState(() => _isStatsCollapsed = !_isStatsCollapsed),
                      ),
                      const SizedBox(width: 8),
                      _GlassBtn(
                        icon: Icons.refresh_rounded,
                        onTap: () => ref
                            .read(leaveProvider.notifier)
                            .fetchLeaves(forceRefresh: true),
                      ),
                      const SizedBox(width: 8),
                      _GlassBtn(
                        icon: Icons.add_rounded,
                        onTap: () => _showApplySheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  if (!_isStatsCollapsed) ...[
                    _StatsBar(state: state, primary: primary),
                    const SizedBox(height: 12),
                  ],

                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: primary,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: 'Upcoming'),
                        Tab(text: 'Past Leaves'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            _tabController.index == 0
                ? _UpcomingTab(
                    state: state,
                    primary: primary,
                    leaveTypes: _leaveTypes,
                    isTeacher: isTeacher,
                  )
                : _PastTab(
                    state: state,
                    primary: primary,
                  ),
            const SizedBox(height: 80), // FAB clearance
          ],
        ),
      ),
    );
  }

  void _showApplySheet(BuildContext context,
      {LeaveApplication? editLeave}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(
        leaveTypes: _leaveTypes,
        primary: _primary,
        editLeave: editLeave,
      ),
    );

    if (result == true && context.mounted) {
      _showSuccessDialog(context, _primary, editLeave != null);
      ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true);
    }
  }
}

// ─── Stats bar widget ─────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final LeaveState state;
  final Color primary;

  const _StatsBar({required this.state, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _StatCell(
              value: state.totalQuota.toString(),
              label: 'Quota',
              icon: '📅',
              primary: primary),
          _Vdivider(),
          _StatCell(
              value: state.usedDays.toString(),
              label: 'Used',
              icon: '✅',
              primary: primary),
          _Vdivider(),
          _StatCell(
              value: state.pendingCount.toString(),
              label: 'Pending',
              icon: '⏳',
              primary: primary),
          _Vdivider(),
          _StatCell(
              value: state.balanceDays.toString(),
              label: 'Balance',
              icon: '💰',
              primary: primary),
        ],
      ),
    );
  }
}

class _Vdivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 32, width: 1, color: Colors.white.withValues(alpha: 0.3));
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  final Color primary;

  const _StatCell(
      {required this.value,
      required this.label,
      required this.icon,
      required this.primary});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Global helpers ───────────────────────────────────────────────────────────

void _cancelOrDeleteLeaveHelper(
    BuildContext context, WidgetRef ref, LeaveApplication leave, bool isPending) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isPending ? '⚠️ Cancel Leave?' : '🗑️ Delete Record?',
        style: const TextStyle(
            fontFamily: AppFonts.heading, fontWeight: FontWeight.w800),
      ),
      content: Text(
        isPending
            ? 'Are you sure you want to cancel this leave application?'
            : 'This will permanently delete this leave record.',
        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Keep'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final success = await ref
                .read(leaveProvider.notifier)
                .cancelOrDeleteLeave(leave.id);
            if (success) {
              ref
                  .read(leaveProvider.notifier)
                  .fetchLeaves(forceRefresh: true);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(success
                    ? (isPending
                        ? '✅ Leave cancelled successfully'
                        : '🗑️ Record deleted')
                    : '❌ Failed. Please try again.'),
                backgroundColor: success
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(isPending ? 'Cancel Leave' : 'Delete'),
        ),
      ],
    ),
  );
}

List<AzureGridColumn<LeaveApplication>> _buildLeaveGridColumns(BuildContext context, WidgetRef ref) {
  return [
    AzureGridColumn<LeaveApplication>(
      label: 'Leave Type',
      width: 140.0,
      compare: (a, b) => a.leaveType.compareTo(b.leaveType),
      cellBuilder: (leave) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_leaveIcon(leave.leaveType), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(leave.leaveType, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    ),
    AzureGridColumn<LeaveApplication>(
      label: 'Duration',
      width: 200.0,
      compare: (a, b) {
        final da = a.durationDays ?? _calcDays(a.startDate, a.endDate);
        final db = b.durationDays ?? _calcDays(b.startDate, b.endDate);
        return da.compareTo(db);
      },
      cellBuilder: (leave) {
        final days = leave.durationDays ?? _calcDays(leave.startDate, leave.endDate);
        return Text('$days days (${_fmtDate(leave.startDate)} → ${_fmtDate(leave.endDate)})');
      },
    ),
    AzureGridColumn<LeaveApplication>(
      label: 'Reason',
      width: 220.0,
      cellBuilder: (leave) => Text(leave.reason, overflow: TextOverflow.ellipsis),
    ),
    AzureGridColumn<LeaveApplication>(
      label: 'Status',
      width: 110.0,
      compare: (a, b) => a.status.compareTo(b.status),
      cellBuilder: (leave) {
        final isPending = leave.status == 'pending';
        final isApproved = leave.status == 'approved';
        final isRejected = leave.status == 'rejected';

        Color statusColor;
        Color statusBg;
        String statusLabel;
        if (isPending) {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFFF7ED);
          statusLabel = '⏳ Pending';
        } else if (isApproved) {
          statusColor = const Color(0xFF059669);
          statusBg = const Color(0xFFECFDF5);
          statusLabel = '✅ Approved';
        } else if (isRejected) {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEF2F2);
          statusLabel = '❌ Rejected';
        } else {
          statusColor = const Color(0xFF64748B);
          statusBg = const Color(0xFFF1F5F9);
          statusLabel = '🚫 Cancelled';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
          ),
        );
      },
    ),
    AzureGridColumn<LeaveApplication>(
      label: 'Action',
      width: 110.0,
      cellBuilder: (leave) {
        final isPending = leave.status == 'pending';
        final isCancelable = isPending;
        final isDeletable = leave.status == 'rejected' || leave.status == 'cancelled';
        if (!isCancelable && !isDeletable) return const SizedBox();
        return SizedBox(
          height: 26,
          child: ElevatedButton(
            onPressed: () => _cancelOrDeleteLeaveHelper(context, ref, leave, isPending),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Text(isPending ? 'Cancel' : 'Delete', style: const TextStyle(fontSize: 10, color: Colors.white)),
          ),
        );
      },
    ),
  ];
}

// ─── Upcoming tab ─────────────────────────────────────────────────────────────

class _UpcomingTab extends ConsumerWidget {
  final LeaveState state;
  final Color primary;
  final List<String> leaveTypes;
  final bool isTeacher;

  const _UpcomingTab({
    required this.state,
    required this.primary,
    required this.leaveTypes,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.applications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return _ErrorView(
          message: state.error!,
          onRetry: () {
            ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true);
          });
    }

    final upcoming = state.upcomingLeaves;

    if (Responsive.isWide(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: AzureGrid<LeaveApplication>(
          title: 'Upcoming Applications',
          items: upcoming,
          columns: _buildLeaveGridColumns(context, ref),
          searchMatcher: (leave) => '${leave.leaveType} ${leave.reason} ${leave.status}',
          onRefresh: () => ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true),
          mobileCardBuilder: (context, leave) => const SizedBox(),
          disableVerticalScroll: true,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        children: [
          if (upcoming.isEmpty)
            const _EmptyState(
              message: 'No upcoming leaves',
              subMessage: 'Tap + to apply for a new leave',
              icon: '🗓️',
            )
          else ...[
            ...upcoming.map((leave) => _LeaveCard(
                  leave: leave,
                  primary: primary,
                  isUpcoming: true,
                )),
          ],
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }
}

// ─── Past tab ─────────────────────────────────────────────────────────────────

class _PastTab extends ConsumerWidget {
  final LeaveState state;
  final Color primary;

  const _PastTab({required this.state, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.applications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return _ErrorView(
          message: state.error!,
          onRetry: () {
            ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true);
          });
    }

    final past = state.pastLeaves;

    if (Responsive.isWide(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        child: AzureGrid<LeaveApplication>(
          title: 'Past Applications History',
          items: past,
          columns: _buildLeaveGridColumns(context, ref),
          searchMatcher: (leave) => '${leave.leaveType} ${leave.reason} ${leave.status}',
          onRefresh: () => ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true),
          mobileCardBuilder: (context, leave) => const SizedBox(),
          disableVerticalScroll: true,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true),
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        children: [
          if (past.isEmpty)
            const _EmptyState(
              message: 'No past leaves',
              subMessage: 'Your leave history will appear here',
              icon: '📜',
            )
          else ...[
            ...past.map((leave) => _LeaveCard(
                  leave: leave,
                  primary: primary,
                  isUpcoming: false,
                )),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Leave Card ───────────────────────────────────────────────────────────────

class _LeaveCard extends ConsumerWidget {
  final LeaveApplication leave;
  final Color primary;
  final bool isUpcoming;

  const _LeaveCard({
    required this.leave,
    required this.primary,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = leave.status == 'pending';
    final isApproved = leave.status == 'approved';
    final isRejected = leave.status == 'rejected';
    // isCancelled: status == 'cancelled'

    Color statusColor;
    Color statusBg;
    String statusLabel;
    if (isPending) {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFF7ED);
      statusLabel = '⏳ Pending';
    } else if (isApproved) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusLabel = '✅ Approved';
    } else if (isRejected) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusLabel = '❌ Rejected';
    } else {
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFFF1F5F9);
      statusLabel = '🚫 Cancelled';
    }

    // Compute duration
    int days = leave.durationDays ?? _calcDays(leave.startDate, leave.endDate);
    final formattedRange =
        '${_fmtDate(leave.startDate)} → ${_fmtDate(leave.endDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending
              ? primary.withValues(alpha: 0.25)
              : isApproved
                  ? const Color(0xFF059669).withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon bubble
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _leaveIcon(leave.leaveType),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.leaveType,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            formattedRange,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            '$days ${days == 1 ? "day" : "days"}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Reason preview ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                leave.reason,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // ── Rejection reason ─────────────────────────────────────────
          if (isRejected && leave.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Rejection Reason: ${leave.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDC2626),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Action buttons ───────────────────────────────────────────
          if (isUpcoming && (isPending || isApproved)) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (isPending)
                    Expanded(
                      child: _ActionBtn(
                        label: 'Edit',
                        icon: Icons.edit_rounded,
                        color: primary,
                        bgColor: primary.withValues(alpha: 0.08),
                        onTap: () => _showEditSheet(context, ref),
                      ),
                    ),
                  if (isPending) const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: isPending ? 'Cancel' : 'Withdraw',
                      icon: isPending
                          ? Icons.cancel_outlined
                          : Icons.undo_rounded,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                      onTap: () =>
                          _confirmCancelOrDelete(context, ref, isPending),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (!isUpcoming &&
              (leave.status == 'rejected' || leave.status == 'cancelled')) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _ActionBtn(
                label: 'Delete Record',
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => _confirmCancelOrDelete(context, ref, false),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) async {
    final isTeacher = ref.read(authProvider).role == UserRole.teacher;
    final types = isTeacher ? _teacherLeaveTypes : _studentLeaveTypes;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(
        leaveTypes: types,
        primary: primary,
        editLeave: leave,
      ),
    );

    if (result == true && context.mounted) {
      _showSuccessDialog(context, primary, true);
      ref.read(leaveProvider.notifier).fetchLeaves(forceRefresh: true);
    }
  }

  void _confirmCancelOrDelete(
      BuildContext context, WidgetRef ref, bool isPending) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isPending ? '⚠️ Cancel Leave?' : '🗑️ Delete Record?',
          style: const TextStyle(
              fontFamily: AppFonts.heading, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isPending
              ? 'Are you sure you want to cancel this leave application?'
              : 'This will permanently delete this leave record.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(leaveProvider.notifier)
                  .cancelOrDeleteLeave(leave.id);
              if (success) {
                ref
                    .read(leaveProvider.notifier)
                    .fetchLeaves(forceRefresh: true);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success
                      ? (isPending
                          ? '✅ Leave cancelled successfully'
                          : '🗑️ Record deleted')
                      : '❌ Failed. Please try again.'),
                  backgroundColor: success
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isPending ? 'Cancel Leave' : 'Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Apply / Edit Leave bottom sheet ─────────────────────────────────────────

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  final List<String> leaveTypes;
  final Color primary;
  final LeaveApplication? editLeave;

  const _ApplyLeaveSheet({
    required this.leaveTypes,
    required this.primary,
    this.editLeave,
  });

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  // Attachment state variables
  String? _attachmentUrl;
  String? _attachmentName;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editLeave;
    _selectedType = e?.leaveType ??
        (widget.leaveTypes.isNotEmpty ? widget.leaveTypes.first : 'Others');
    if (e != null) {
      _startDate = DateTime.tryParse(e.startDate);
      _endDate = DateTime.tryParse(e.endDate);
      _reasonCtrl.text = e.reason;
      _attachmentUrl = e.attachmentUrl;
      if (_attachmentUrl != null && _attachmentUrl!.isNotEmpty) {
        _attachmentName = _attachmentUrl!.split('/').last.split('?').first;
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.editLeave != null;

  int get _leaveDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? (_startDate ?? now).add(const Duration(days: 1)));
    final first = isStart ? now : (_startDate ?? now);
    final last = now.add(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(primary: widget.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final name = file.name;

        if (bytes == null) {
          _showError('Could not read file data.');
          return;
        }

        setState(() => _isUploadingAttachment = true);

        final url = await ref
            .read(leaveProvider.notifier)
            .uploadAttachment(bytes, name);

        setState(() {
          _isUploadingAttachment = false;
          if (url != null) {
            _attachmentUrl = url;
            _attachmentName = name;
          }
        });
      }
    } catch (e) {
      setState(() => _isUploadingAttachment = false);
      _showError('Error picking file: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Please select both start and end dates.');
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      _showError('End date must be on or after start date.');
      return;
    }

    setState(() => _isSubmitting = true);

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    bool success;
    if (_isEditing) {
      success = await ref.read(leaveProvider.notifier).editLeave(
            leaveId: widget.editLeave!.id,
            leaveType: _selectedType,
            startDate: fmt(_startDate!),
            endDate: fmt(_endDate!),
            reason: _reasonCtrl.text.trim(),
            attachmentUrl: _attachmentUrl ?? "",
          );
    } else {
      success = await ref.read(leaveProvider.notifier).submitLeave(
            leaveType: _selectedType,
            startDate: fmt(_startDate!),
            endDate: fmt(_endDate!),
            reason: _reasonCtrl.text.trim(),
            attachmentUrl: _attachmentUrl,
          );
    }

    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true); // Return true indicating success!
    } else {
      final err = ref.read(leaveProvider).error ?? 'Something went wrong';
      _showError(err);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFDC2626),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                children: [
                  Text(
                    _isEditing ? '✏️ Edit Leave' : '📋 Apply for Leave',
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Leave type dropdown
              const _FieldLabel('Leave Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: widget.leaveTypes.contains(_selectedType)
                    ? _selectedType
                    : widget.leaveTypes.first,
                decoration: _inputDeco('Select leave type'),
                items: widget.leaveTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Row(children: [
                            Text(_leaveIcon(t),
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(t, style: const TextStyle(fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please select a leave type'
                    : null,
              ),
              const SizedBox(height: 14),

              // Date row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('From Date'),
                        const SizedBox(height: 6),
                        _DatePicker(
                          label: _startDate != null
                              ? _fmtDate(
                                  _startDate!.toIso8601String().split('T')[0])
                              : 'Select Date',
                          icon: Icons.calendar_month_rounded,
                          primary: widget.primary,
                          onTap: () => _pickDate(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('To Date'),
                        const SizedBox(height: 6),
                        _DatePicker(
                          label: _endDate != null
                              ? _fmtDate(
                                  _endDate!.toIso8601String().split('T')[0])
                              : 'Select Date',
                          icon: Icons.calendar_month_rounded,
                          primary: widget.primary,
                          onTap: () => _pickDate(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Duration pill
              if (_leaveDays > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '📅 $_leaveDays ${_leaveDays == 1 ? "day" : "days"} of leave',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: widget.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Reason
              const _FieldLabel('Reason for Leave'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: _inputDeco('Describe the reason for your leave...'),
                style: const TextStyle(fontSize: 13),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please provide a reason';
                  }
                  if (v.trim().length < 10) {
                    return 'Reason should be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Attachment section
              const _FieldLabel('Supporting Document (Optional)'),
              const SizedBox(height: 6),
              if (_isUploadingAttachment)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 8),
                        Text(
                          'Uploading document...',
                          style:
                              TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_attachmentUrl != null && _attachmentUrl!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: widget.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(12),
                    color: widget.primary.withValues(alpha: 0.06),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _attachmentName?.endsWith('.pdf') == true
                            ? '📕'
                            : '🖼️',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachmentName ?? 'Document.pdf',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: widget.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Uploaded successfully',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFDC2626)),
                        onPressed: () {
                          setState(() {
                            _attachmentUrl = null;
                            _attachmentName = null;
                          });
                        },
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: _pickAttachment,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Column(
                      children: [
                        Text('📎', style: TextStyle(fontSize: 22)),
                        SizedBox(height: 4),
                        Text(
                          'Attach Supporting Document',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Medical note, slip, etc.',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Leave' : '🚀 Submit Application',
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      );
}

class _DatePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color primary;
  final VoidCallback onTap;

  const _DatePicker({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = label != 'Select Date';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasDate
              ? primary.withValues(alpha: 0.06)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: hasDate
                ? primary.withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15, color: hasDate ? primary : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                  color: hasDate ? primary : const Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final String subMessage;
  final String icon;

  const _EmptyState(
      {required this.message, required this.subMessage, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subMessage,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Could not load leaves',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input decoration helper ──────────────────────────────────────────────────

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

// ─── Date formatting helpers ──────────────────────────────────────────────────

String _fmtDate(String iso) {
  try {
    final d = DateTime.parse(iso);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  } catch (_) {
    return iso;
  }
}

int _calcDays(String start, String end) {
  try {
    final s = DateTime.parse(start);
    final e = DateTime.parse(end);
    return e.difference(s).inDays + 1;
  } catch (_) {
    return 1;
  }
}

void _showSuccessDialog(BuildContext ctx, Color primaryColor, bool isEditing) {
  showDialog(
    context: ctx,
    builder: (dialogCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Center(
              child: Text('✅', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEditing ? 'Leave Updated!' : 'Leave Applied!',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEditing
                ? 'Your leave application has been updated.'
                : 'Your leave request has been submitted and is pending approval.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Great!',
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  );
}
