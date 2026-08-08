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
  final Function(String status, String? reason) onRSVP;
  final Function(String commentText) onAddComment;

  const EventDetailDialog({
    super.key,
    required this.schedule,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
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
    final isOrganizer = s.organizerId == currentUserId ||
        s.createdBy == currentUserId ||
        (s.organizerId == null && s.createdBy == null);

    // Sync comments if live list has more comments
    if (s.comments.length > _comments.length) {
      _comments = List.from(s.comments);
    }

    // Tally RSVP metrics for Organizer
    final acceptedCount = s.participants.where((p) => p.rsvpStatus == 'accepted').length;
    final declinedCount = s.participants.where((p) => p.rsvpStatus == 'declined').length;
    final tentativeCount = s.participants.where((p) => p.rsvpStatus == 'tentative').length;
    final pendingCount = s.participants.where((p) => p.rsvpStatus == 'pending' || p.rsvpStatus.isEmpty).length;

    final timeSpan = '${DateFormat('EEEE, d MMMM yyyy').format(s.startTime)}\n${DateFormat('hh:mm a').format(s.startTime)} – ${DateFormat('hh:mm a').format(s.endTime)}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.1),
                border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
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
                  if (isOrganizer) ...[
                    const SizedBox(width: 8),
                    Container(
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
                          Text(
                            'Owner / Organizer',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
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
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Delete',
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onDelete();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Title
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date & Time Banner
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          timeSpan,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Location
                  if (s.locationName != null || s.room != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 12),
                        Text(
                          '${s.locationName ?? ""} ${s.room != null ? "• Room ${s.room!}" : ""}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                          const Icon(Icons.videocam_rounded, color: Color(0xFF4F46E5), size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Join Video Conference',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                            ),
                          ),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Description
                  if (s.description != null && s.description!.isNotEmpty) ...[
                    const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text(
                      s.description!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Participants & Response Breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOrganizer ? 'Attendee Responses (${s.participants.length})' : 'Participants & Assignments',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      if (isOrganizer && s.participants.isNotEmpty)
                        Row(
                          children: [
                            _buildRSVPCountChip('Accepted', acceptedCount, const Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            _buildRSVPCountChip('Declined', declinedCount, const Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            _buildRSVPCountChip('Tentative', tentativeCount, const Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            _buildRSVPCountChip('Pending', pendingCount, const Color(0xFF94A3B8)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (s.participants.isEmpty)
                    const Text('No external participants assigned.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  else
                    Column(
                      children: s.participants.map((p) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF4F46E5),
                                child: Text(
                                  (p.fullName ?? "U")[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.fullName ?? "User"} (${p.role ?? "Staff"})',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    if (p.declineReason != null && p.declineReason!.isNotEmpty)
                                      Text(
                                        'Note: ${p.declineReason}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontStyle: FontStyle.italic),
                                      ),
                                  ],
                                ),
                              ),
                              _buildRSVPStatusBadge(p.rsvpStatus),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // RSVP Response Section for Attendees
                  if (!isOrganizer) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Response', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
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
                              'Status: ${_myRSVPStatus!.toUpperCase()}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'accepted');
                            widget.onRSVP('accepted', null);
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                          label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _myRSVPStatus == 'accepted' ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                            foregroundColor: _myRSVPStatus == 'accepted' ? Colors.white : const Color(0xFF10B981),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'declined');
                            widget.onRSVP('declined', 'Unavailable at this time');
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _myRSVPStatus == 'declined' ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
                            foregroundColor: _myRSVPStatus == 'declined' ? Colors.white : const Color(0xFFEF4444),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _myRSVPStatus = 'tentative');
                            widget.onRSVP('tentative', null);
                          },
                          icon: const Icon(Icons.help_outline_rounded, size: 16),
                          label: const Text('Tentative', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _myRSVPStatus == 'tentative' ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                            foregroundColor: _myRSVPStatus == 'tentative' ? Colors.white : const Color(0xFFF59E0B),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                  ],

                  // Activity & Discussion (Live Persistent Comments)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activity & Discussion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text('${_comments.length} Comments', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
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
                                Text(c.fullName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                const SizedBox(width: 6),
                                Text('• ${DateFormat('d MMM, hh:mm a').format(c.createdAt)}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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
                            hintText: 'Write a comment or note (Press Enter)...',
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

  Widget _buildRSVPCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildRSVPStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
