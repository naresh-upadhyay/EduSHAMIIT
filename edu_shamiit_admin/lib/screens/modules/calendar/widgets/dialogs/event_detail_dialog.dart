import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import '../../models/calendar_models.dart';
import '../../providers/calendar_provider.dart';

class EventDetailDialog extends ConsumerStatefulWidget {
  final ScheduleModel schedule;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final Function(String reason)? onCancel;
  final Function(String status, String? reason) onRSVP;
  final Function(String commentText) onAddComment;

  const EventDetailDialog({
    super.key,
    required this.schedule,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.onCancel,
    required this.onRSVP,
    required this.onAddComment,
  });

  @override
  ConsumerState<EventDetailDialog> createState() => _EventDetailDialogState();
}

class _EventDetailDialogState extends ConsumerState<EventDetailDialog> {
  final _commentController = TextEditingController();
  late List<ScheduleCommentModel> _comments;
  String? _myRSVPStatus;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.schedule.comments);
    
    // Look up if user has already responded
    final user = ref.read(authProvider).userData;
    final currentUserId = user?['id']?.toString();
    if (currentUserId != null) {
      for (final p in widget.schedule.participants) {
        if (p.userId == currentUserId && p.rsvpStatus != 'pending') {
          _myRSVPStatus = p.rsvpStatus;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      widget.onAddComment(text);
      final user = ref.read(authProvider).userData;
      final userName = user?['full_name']?.toString() ?? 'You';

      setState(() {
        _comments.add(
          ScheduleCommentModel(
            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
            userId: user?['id']?.toString() ?? 'current_user',
            fullName: userName,
            commentText: text,
            createdAt: DateTime.now(),
          ),
        );
        _commentController.clear();
      });
    }
  }

  void _showCancelReasonDialog(BuildContext context, ScheduleModel s) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 24),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Cancel Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for cancelling this schedule so all participants are informed.',
                style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter cancellation reason...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Keep Schedule', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.block_rounded, size: 16),
              label: const Text('Confirm'),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a cancellation reason.')),
                  );
                  return;
                }
                Navigator.pop(dlgCtx);
                Navigator.pop(context);
                if (widget.onCancel != null) {
                  widget.onCancel!(reason);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch live schedule in state if available
    final calState = ref.watch(calendarProvider);
    final liveSchedule = calState.schedules.firstWhere(
      (s) => s.id == widget.schedule.id || s.id == widget.schedule.id.split('_inst_')[0],
      orElse: () => widget.schedule,
    );

    final s = liveSchedule;
    final user = ref.watch(authProvider).userData;
    final currentUserId = user?['id']?.toString();
    final userRole = user?['role']?.toString().toLowerCase() ?? '';

    // Participant permission check
    ScheduleParticipantModel? myParticipant;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      try {
        myParticipant = s.participants.firstWhere((p) => p.userId == currentUserId);
      } catch (_) {}
    }

    final pPerm = myParticipant?.permission.toLowerCase() ?? 'can_view';
    final hasWritePerm = pPerm == 'read_write' || pPerm == 'can_edit' || pPerm == 'can_manage';

    final isOwner = s.organizerId == currentUserId ||
        s.createdBy == currentUserId ||
        userRole == 'super_admin' ||
        userRole == 'admin' ||
        userRole == 'owner' ||
        (s.organizerId == null && s.createdBy == null);

    final isOrganizer = isOwner;
    final canManage = isOwner || hasWritePerm;

    // Sync comments if live list has more comments
    if (s.comments.length > _comments.length) {
      _comments = List.from(s.comments);
    }

    // Tally RSVP metrics for Organizer
    final acceptedCount = s.participants.where((p) => p.rsvpStatus == 'accepted').length;
    final declinedCount = s.participants.where((p) => p.rsvpStatus == 'declined').length;
    final tentativeCount = s.participants.where((p) => p.rsvpStatus == 'tentative').length;
    final pendingCount = s.participants.where((p) => p.rsvpStatus == 'pending' || p.rsvpStatus.isEmpty).length;

    // Responsive measurements
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1100;

    // Fluid text scale: 0.72 at 270px → 1.0 at 550px+
    final double ts = (screenWidth / 550).clamp(0.72, 1.0);

    final timeSpan = isMobile
        ? '${DateFormat('EEE, d MMM yyyy').format(s.startTime)}\n${DateFormat('hh:mm a').format(s.startTime)} \u2013 ${DateFormat('hh:mm a').format(s.endTime)}'
        : '${DateFormat('EEEE, d MMMM yyyy').format(s.startTime)}\n${DateFormat('hh:mm a').format(s.startTime)} \u2013 ${DateFormat('hh:mm a').format(s.endTime)}';

    final dialogWidth = isMobile
        ? screenWidth - 16
        : (isTablet ? (screenWidth * 0.75).clamp(400.0, 620.0) : 620.0);
    final dialogMaxHeight = isMobile
        ? screenHeight * 0.94
        : (screenHeight * 0.85).clamp(400.0, 720.0);
    final dialogPadding = EdgeInsets.symmetric(
      horizontal: isMobile ? 8 : 24,
      vertical: isMobile ? 8 : 24,
    );
    final contentPadding = EdgeInsets.symmetric(
      horizontal: isMobile ? 10 : 24,
      vertical: isMobile ? 10 : 24,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: dialogPadding,
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Modal Top Header
            _buildHeader(context, s, canManage, isOwner, isMobile),

            // Main Content Area
            Expanded(
              child: ListView(
                padding: contentPadding,
                children: [
                  // Cancelled Banner
                  if (s.status == 'cancelled') ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'THIS SCHEDULE HAS BEEN CANCELLED',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                                ),
                                if (s.cancellationReason != null && s.cancellationReason!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${s.cancellationReason}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Title
                  Text(
                    s.title,
                    style: TextStyle(
                      fontSize: (20 * ts).roundToDouble(),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 14),

                  // Attendance Requirement Banner
                  _buildAttendanceRoleBanner(context, s),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time_rounded, size: (18 * ts).roundToDouble(), color: const Color(0xFF4F46E5)),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          timeSpan,
                          style: TextStyle(fontSize: (13 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 10 : 14),

                  // Location
                  if (s.locationName != null || s.room != null) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: (18 * ts).roundToDouble(), color: const Color(0xFF64748B)),
                        SizedBox(width: isMobile ? 8 : 12),
                        Expanded(
                          child: Text(
                            '${s.locationName ?? ""} ${s.room != null ? "\u2022 Room ${s.room!}" : ""}',
                            style: TextStyle(fontSize: (13 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 10 : 14),
                  ],

                  // Virtual Video Meeting
                  if (s.virtualMeetingUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.videocam_rounded, color: const Color(0xFF4F46E5), size: (20 * ts).roundToDouble()),
                          SizedBox(width: isMobile ? 6 : 10),
                          Expanded(
                            child: Text(
                              isMobile ? 'Video Conference' : 'Join Video Conference',
                              style: TextStyle(fontSize: (13 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final uri = Uri.parse(s.virtualMeetingUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(isMobile ? 'Join' : 'Join Now', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Description
                  if (s.description != null && s.description!.isNotEmpty) ...[
                    Text('Description', style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(
                      s.description!,
                      style: TextStyle(fontSize: (13 * ts).roundToDouble(), color: const Color(0xFF334155), height: 1.4),
                    ),
                    SizedBox(height: isMobile ? 12 : 18),
                  ],

                  // Participants & Response Breakdown
                  if (canManage) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOrganizer ? 'Attendee Responses (${s.participants.length})' : 'Participants & Assignments',
                          style: TextStyle(fontSize: (13 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        if (isOrganizer && s.participants.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _buildRSVPCountChip('Accepted', acceptedCount, const Color(0xFF10B981)),
                              _buildRSVPCountChip('Declined', declinedCount, const Color(0xFFEF4444)),
                              _buildRSVPCountChip('Tentative', tentativeCount, const Color(0xFFF59E0B)),
                              _buildRSVPCountChip('Pending', pendingCount, const Color(0xFF94A3B8)),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (s.participants.isEmpty)
                      const Text('No external participants assigned.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                    else
                      Column(
                        children: s.participants.map((p) {
                          return _buildParticipantRow(p, isMobile);
                        }).toList(),
                      ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                  ],

                  // RSVP Response Section for Attendees
                  if (!isOrganizer) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Your Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        ),
                        if (_myRSVPStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _myRSVPStatus == 'accepted'
                                  ? const Color(0xFF10B981)
                                  : _myRSVPStatus == 'declined'
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _myRSVPStatus!.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRSVPButton(
                          label: 'Accept',
                          icon: Icons.check_circle_outline_rounded,
                          status: 'accepted',
                          activeColor: const Color(0xFF10B981),
                          isMobile: isMobile,
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'accepted');
                            widget.onRSVP('accepted', null);
                          },
                        ),
                        _buildRSVPButton(
                          label: 'Decline',
                          icon: Icons.cancel_outlined,
                          status: 'declined',
                          activeColor: const Color(0xFFEF4444),
                          isMobile: isMobile,
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'declined');
                            widget.onRSVP('declined', 'Unavailable at this time');
                          },
                        ),
                        _buildRSVPButton(
                          label: 'Tentative',
                          icon: Icons.help_outline_rounded,
                          status: 'tentative',
                          activeColor: const Color(0xFFF59E0B),
                          isMobile: isMobile,
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'tentative');
                            widget.onRSVP('tentative', null);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                  ],

                  // Activity & Discussion
                  Row(
                    children: [
                      Expanded(
                        child: Text('Activity & Discussion', style: TextStyle(fontSize: (13 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                      ),
                      Text('${_comments.length} Comments', style: TextStyle(fontSize: (11 * ts).roundToDouble(), fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'No messages yet. Post the first update or agenda note below.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._comments.map((c) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: const Color(0xFF4F46E5),
                                  child: Text(
                                    c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    c.fullName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '\u2022 ${DateFormat('d MMM, hh:mm a').format(c.createdAt)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(c.commentText, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          onSubmitted: (_) => _submitComment(),
                          decoration: InputDecoration(
                            hintText: isMobile ? 'Write a comment...' : 'Write a comment or note (Press Enter)...',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _submitComment,
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                        tooltip: 'Send comment',
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

  // Responsive Header
  Widget _buildHeader(BuildContext context, ScheduleModel s, bool canManage, bool isOwner, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.1),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          // Schedule type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.scheduleType,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          // Owner badge - only on non-mobile
          if (isOwner && !isMobile) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Owner / Organizer',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Action icons: on mobile use PopupMenuButton, on desktop show individual icons
          if (canManage) ...[
            if (isMobile)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey.shade700),
                tooltip: 'Actions',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  switch (action) {
                    case 'edit':
                      Navigator.pop(context);
                      widget.onEdit();
                      break;
                    case 'duplicate':
                      Navigator.pop(context);
                      widget.onDuplicate();
                      break;
                    case 'cancel':
                      _showCancelReasonDialog(context, s);
                      break;
                    case 'delete':
                      Navigator.pop(context);
                      widget.onDelete();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 10),
                        Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded, size: 16, color: Color(0xFF475569)),
                        SizedBox(width: 10),
                        Text('Duplicate', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (s.status != 'cancelled')
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, size: 16, color: Color(0xFFD97706)),
                          SizedBox(width: 10),
                          Text('Cancel Schedule', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                tooltip: 'Edit schedule',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEdit();
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF475569)),
                tooltip: 'Duplicate',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDuplicate();
                },
              ),
              if (s.status != 'cancelled')
                IconButton(
                  icon: const Icon(Icons.block_rounded, size: 18, color: Color(0xFFD97706)),
                  tooltip: 'Cancel Schedule with Reason',
                  onPressed: () => _showCancelReasonDialog(context, s),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                tooltip: 'Hard Delete',
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
              ),
            ],
          ] else ...[
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Read Only',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // Participant Row (Responsive)
  Widget _buildParticipantRow(ScheduleParticipantModel p, bool isMobile) {
    final pRole = p.participationRole.toLowerCase();
    final isReq = pRole == 'required' || pRole == 'mandatory';
    final isOpt = pRole == 'optional';
    final screenW = MediaQuery.sizeOf(context).width;
    final double ts = (screenW / 700).clamp(0.78, 1.0);

    // Build display name
    String displayName;
    if (p.userId == null || p.userId!.isEmpty || p.participantType == "role" || p.participantType == "class") {
      displayName = '${p.fullName ?? "User"} (Group)';
    } else {
      displayName = p.fullName ?? 'User';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isMobile ? 10 : 12,
            backgroundColor: const Color(0xFF4F46E5),
            child: Text(
              (p.fullName ?? "U")[0].toUpperCase(),
              style: TextStyle(fontSize: (10 * ts).roundToDouble(), color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (p.declineReason != null && p.declineReason!.isNotEmpty)
                  Text(
                    'Note: ${p.declineReason}',
                    style: TextStyle(fontSize: (9 * ts).roundToDouble(), color: const Color(0xFFEF4444), fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6, vertical: 2),
            decoration: BoxDecoration(
              color: isReq
                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                  : (isOpt ? const Color(0xFF3B82F6).withValues(alpha: 0.12) : const Color(0xFF8B5CF6).withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isReq ? 'REQ' : (isOpt ? 'OPT' : 'FYI'),
              style: TextStyle(
                fontSize: (8 * ts).roundToDouble(),
                fontWeight: FontWeight.w800,
                color: isReq
                    ? const Color(0xFFEF4444)
                    : (isOpt ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _buildRSVPStatusBadge(p.rsvpStatus),
        ],
      ),
    );
  }

  // RSVP Response Button
  Widget _buildRSVPButton({
    required String label,
    required IconData icon,
    required String status,
    required Color activeColor,
    required bool isMobile,
    required VoidCallback onPressed,
  }) {
    final isActive = _myRSVPStatus == status;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? activeColor : const Color(0xFFF1F5F9),
        foregroundColor: isActive ? Colors.white : activeColor,
        elevation: 0,
        side: BorderSide(color: activeColor),
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildRSVPCountChip(String label, int count, Color color) {
    final screenW = MediaQuery.sizeOf(context).width;
    final double ts = (screenW / 700).clamp(0.78, 1.0);
    final isMobile = screenW < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isMobile ? '$count' : '$label: $count',
        style: TextStyle(fontSize: (10 * ts).roundToDouble(), fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildRSVPStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    final screenW = MediaQuery.sizeOf(context).width;
    final double ts = (screenW / 700).clamp(0.78, 1.0);

    switch (status.toLowerCase()) {
      case 'accepted':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        text = 'Accepted';
        break;
      case 'declined':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        text = 'Declined';
        break;
      case 'tentative':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        text = 'Tentative';
        break;
      default:
        bg = const Color(0xFF94A3B8).withValues(alpha: 0.12);
        fg = const Color(0xFF64748B);
        text = 'Awaiting';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: screenW < 600 ? 5 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: (9 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildAttendanceRoleBanner(BuildContext context, ScheduleModel s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider).userData;
    final currentUserId = currentUser?['id']?.toString();
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final double ts = (MediaQuery.sizeOf(context).width / 700).clamp(0.78, 1.0);

    ScheduleParticipantModel? myParticipant;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      try {
        myParticipant = s.participants.firstWhere((p) => p.userId == currentUserId);
      } catch (_) {}
    }

    if (myParticipant == null) {
      return const SizedBox.shrink();
    }

    final role = myParticipant.participationRole.toLowerCase();
    final isRequired = role == 'required' || role == 'mandatory';
    final isOptional = role == 'optional';

    final Color bg = isRequired
        ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
        : (isOptional
            ? (isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF)));
    final Color border = isRequired
        ? const Color(0xFFEF4444)
        : (isOptional ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6));
    final Color textColor = isRequired
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
        : (isOptional
            ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
            : (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8)));
    final IconData icon = isRequired
        ? Icons.error_outline_rounded
        : (isOptional ? Icons.info_outline_rounded : Icons.bookmark_outline_rounded);
    final String label = isRequired
        ? (isMobile ? 'Required Attendance' : 'Mandatory / Required Attendance')
        : (isOptional ? 'Optional Attendance' : 'FYI / Informational Only');

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 16),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14, vertical: isMobile ? 6 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: (18 * ts).roundToDouble(), color: border),
          SizedBox(width: isMobile ? 6 : 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: (12 * ts).roundToDouble(), fontWeight: FontWeight.w800, color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 8, vertical: 2),
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isRequired ? (isMobile ? 'REQ' : 'MANDATORY') : (isOptional ? 'OPT' : 'FYI'),
              style: TextStyle(fontSize: (9 * ts).roundToDouble(), fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
