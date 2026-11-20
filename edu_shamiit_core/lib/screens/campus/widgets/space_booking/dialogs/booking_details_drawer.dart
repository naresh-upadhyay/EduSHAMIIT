import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/space_booking_models.dart';
import '../../../providers/space_booking_provider.dart';
import '../../../services/space_booking_api_service.dart';
import 'space_conflict_warning_dialog.dart';

class BookingDetailsDrawer extends ConsumerStatefulWidget {
  final SpaceBookingRequestItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BookingDetailsDrawer({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  @override
  ConsumerState<BookingDetailsDrawer> createState() => _BookingDetailsDrawerState();
}

class _BookingDetailsDrawerState extends ConsumerState<BookingDetailsDrawer> {
  final TextEditingController _remarksCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _details;

  // Live Conflict Detection State
  bool _hasConflict = false;
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final data = await SpaceBookingApiService.instance.getDetails(widget.item.id);
      if (data != null && mounted) {
        setState(() => _details = data);
      }
      await _checkSlotConflict();
    } catch (_) {}
  }

  Future<void> _checkSlotConflict() async {
    final item = widget.item;
    if (item.roomId.isEmpty) return;
    try {
      final parsedDate = DateTime.tryParse(item.bookingDate) ?? DateTime.now();
      final res = await SpaceBookingApiService.instance.checkSlotAvailability(
        roomId: item.roomId,
        date: parsedDate,
        startTime: item.startTime,
        endTime: item.endTime,
        excludeBookingId: item.id,
      );
      if (mounted) {
        final currentStatus = _details?['status']?.toString() ?? item.status;
        setState(() {
          _hasConflict = res['has_conflict'] == true || currentStatus == 'Conflict';
          if (res['has_conflict'] == true) {
            _conflictMessage = res['message']?.toString() ?? 'Collides with an approved booking';
          } else if (currentStatus == 'Conflict') {
            final reason = _details?['rejection_reason']?.toString() ?? item.rejectionReason;
            _conflictMessage = reason.isNotEmpty ? reason : 'Booking marked as Conflict due to overlapping schedule.';
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(spaceBookingProvider.notifier);
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final drawerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final drawerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Drawer(
      width: 480,
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: drawerBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.bookingRef.isNotEmpty ? item.bookingRef : 'Booking Details',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(item.status, isDark),
                  const SizedBox(width: 4),
                  if (widget.onEdit != null)
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 19, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      tooltip: 'Modify / Edit Schedule',
                      onPressed: widget.onEdit,
                    ),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Schedule',
                      onPressed: widget.onDelete,
                    ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Conflict Warning Alert Card if slot collides with approved booking
                    if (_hasConflict || item.status == 'Conflict' || _details?['status'] == 'Conflict') ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      const Text(
                                        'Approval Conflict Alert',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFEF4444)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('DOUBLE-BOOKING DETECTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _conflictMessage ??
                                        (item.rejectionReason.isNotEmpty
                                            ? item.rejectionReason
                                            : 'This requested slot collides with an approved booking in ${item.spaceDisplay}.'),
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B), fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Approving will be blocked and marked as Conflict to prevent double-booking. Modify schedule or reject.',
                                    style: TextStyle(fontSize: 11, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Space Details Card
                    _buildSectionHeader('Space Information', Icons.room_preferences_outlined, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Space / Room', item.spaceDisplay, textSecondary, textPrimary),
                      _buildInfoRow('Building', item.buildingName, textSecondary, textPrimary),
                      _buildInfoRow('Category / Purpose', '${item.category} • ${item.purpose}', textSecondary, textPrimary),
                      _buildInfoRow('Priority', item.priority, textSecondary, textPrimary),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Schedule & Timings Card
                    _buildSectionHeader('Schedule & Timing', Icons.schedule_outlined, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Date', item.bookingDate, textSecondary, textPrimary),
                      _buildInfoRow('Time Range', '${item.startTime} – ${item.endTime}', textSecondary, textPrimary),
                      _buildInfoRow('Schedule Summary', item.formattedSchedule, textSecondary, textPrimary),
                      _buildInfoRow('Attendees Expected', '${item.attendeeCount} persons', textSecondary, textPrimary),
                      if (item.isRecurring)
                        _buildInfoRow('Series Type', 'Recurring Series', textSecondary, const Color(0xFF3B82F6)),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Organizer Details Card
                    _buildSectionHeader('Organizer / Requester', Icons.person_outline, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Organizer Name', item.organizerName, textSecondary, textPrimary),
                      _buildInfoRow('Institution Role', item.organizerRole, textSecondary, textPrimary),
                      _buildInfoRow('Requested By', item.requestedByDisplay, textSecondary, textPrimary),
                      if (_details?['organizer_email'] != null && (_details!['organizer_email'] as String).isNotEmpty)
                        _buildInfoRow('Contact Email', _details!['organizer_email'] as String, textSecondary, textPrimary),
                      if (_details?['organizer_phone'] != null && (_details!['organizer_phone'] as String).isNotEmpty)
                        _buildInfoRow('Contact Phone', _details!['organizer_phone'] as String, textSecondary, textPrimary),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Amenities & Equipment Card if present
                    if (_details?['amenities_required'] is List && (_details!['amenities_required'] as List).isNotEmpty) ...[
                      _buildSectionHeader('Requested Facilities & Amenities', Icons.videocam_outlined, textPrimary),
                      _buildInfoCard([
                        _buildInfoRow(
                          'Equipment',
                          (_details!['amenities_required'] as List).join(', '),
                          textSecondary,
                          textPrimary,
                        ),
                      ], cardBg, drawerBorder),
                      const SizedBox(height: 16),
                    ],

                    // Special Instructions if present
                    if (_details?['special_instructions'] != null && (_details!['special_instructions'] as String).isNotEmpty) ...[
                      _buildSectionHeader('Special Instructions', Icons.notes_outlined, textPrimary),
                      _buildInfoCard([
                        _buildInfoRow(
                          'Notes',
                          _details!['special_instructions'] as String,
                          textSecondary,
                          textPrimary,
                        ),
                      ], cardBg, drawerBorder),
                      const SizedBox(height: 16),
                    ],

                    // Approval Workflow Status
                    _buildSectionHeader('Approval Progression', Icons.verified_user_outlined, textPrimary),
                    _buildApprovalStepTimeline(item, cardBg, drawerBorder, textPrimary),
                    const SizedBox(height: 16),

                    // Action Comments / Remarks (Only show when item is pending)
                    if (item.status == 'Pending' || item.status == 'Submitted') ...[
                      _buildSectionHeader('Approval / Review Remarks', Icons.chat_bubble_outline, textPrimary),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add review comments or approval notes...',
                          hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: drawerBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: drawerBorder)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: drawerBorder)),
              ),
              child: _buildFooterActions(item, isDark, drawerBorder, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(
    SpaceBookingRequestItem item,
    bool isDark,
    Color drawerBorder,
    SpaceBookingNotifier notifier,
  ) {
    final status = item.status.toLowerCase();
    final isApprovedOrConfirmed = status == 'approved' || status == 'confirmed';
    final isPending = status == 'pending' || status == 'submitted';

    if (isApprovedOrConfirmed) {
      return Row(
        children: [
          if (widget.onDelete != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : widget.onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: BorderSide(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete / Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          if (widget.onDelete != null && widget.onEdit != null)
            const SizedBox(width: 12),
          if (widget.onEdit != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : widget.onEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                label: const Text('Modify Schedule', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      );
    }

    if (isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final scf = ScaffoldMessenger.of(context);
                      setState(() => _isLoading = true);
                      final ok = await notifier.decideApproval(item.id, 'REJECT', comments: _remarksCtrl.text.trim());
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      if (ok) {
                        nav.pop();
                        scf.showSnackBar(SnackBar(content: Text('Booking "${item.title}" has been rejected')));
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          if (widget.onEdit != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Modify Schedule',
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: drawerBorder),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      final nav = Navigator.of(context);
                      final scf = ScaffoldMessenger.of(context);
                      setState(() => _isLoading = true);
                      final res = await notifier.decideApprovalDetailed(item.id, 'APPROVE', comments: _remarksCtrl.text.trim());
                      if (!mounted) return;
                      setState(() => _isLoading = false);
                      if (res['success'] == true) {
                        nav.pop();
                        scf.showSnackBar(
                          SnackBar(
                            content: Text('Booking "${item.title}" approved successfully!'),
                            backgroundColor: const Color(0xFF059669),
                          ),
                        );
                      } else if (res['conflict'] == true) {
                        await _loadDetails();
                        await _checkSlotConflict();
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (ctx) => SpaceConflictWarningDialog(
                            roomName: item.spaceDisplay,
                            requestedTime: '${item.bookingDate} (${item.startTime} - ${item.endTime})',
                            conflictMessage: res['message']?.toString() ?? 'Cannot approve: Space is already booked during this time slot.',
                            onChangeTime: () => Navigator.pop(ctx),
                          ),
                        );
                      } else {
                        scf.showSnackBar(
                          SnackBar(
                            content: Text(res['message']?.toString() ?? 'Failed to approve booking'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }

    // Cancelled / Rejected or Other
    return Row(
      children: [
        if (widget.onDelete != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : widget.onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: BorderSide(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        if (widget.onDelete != null && widget.onEdit != null)
          const SizedBox(width: 12),
        if (widget.onEdit != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : widget.onEdit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: const Text('Re-book / Modify', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, Color cardBg, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textSecondary, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStepTimeline(SpaceBookingRequestItem item, Color cardBg, Color border, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Step 1: Booking Request Submitted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
              ),
              const Text('Done', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.status == 'Approved' || item.status == 'Confirmed'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.status == 'Approved' || item.status == 'Confirmed' ? Icons.check : Icons.access_time,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Step 2: Campus Administrator Approval', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
              ),
              Text(
                item.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.status == 'Approved' || item.status == 'Confirmed'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7);
    Color fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    if (status == 'Approved' || status == 'Confirmed') {
      bg = isDark ? const Color(0xFF065F46).withValues(alpha: 0.5) : const Color(0xFFDCFCE7);
      fg = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    } else if (status == 'Conflict') {
      bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : const Color(0xFFFFE4E6);
      fg = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C);
    } else if (status == 'Rejected' || status == 'Cancelled') {
      bg = isDark ? const Color(0xFF991B1B).withValues(alpha: 0.5) : const Color(0xFFFEE2E2);
      fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
