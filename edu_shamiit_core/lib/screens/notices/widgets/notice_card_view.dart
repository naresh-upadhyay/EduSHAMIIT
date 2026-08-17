import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/notice_models.dart';
import '../providers/notice_provider.dart';
import 'dialogs/create_edit_notice_dialog.dart';
import 'dialogs/notice_detail_dialog.dart';
import 'dialogs/notice_acknowledgements_dialog.dart';

class NoticeCardView extends ConsumerWidget {
  final List<NoticeModel> notices;
  final String userRole;
  final String currentUserId;

  const NoticeCardView({
    super.key,
    required this.notices,
    required this.userRole,
    required this.currentUserId,
  });

  bool get isAdmin {
    final r = userRole.toLowerCase();
    return r == 'super_admin' || r == 'admin' || r == 'principal' || r == 'vice_principal' || r == 'director';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return const Color(0xFFF97316);
      case 'meeting':
        return const Color(0xFF8B5CF6);
      case 'event':
        return const Color(0xFF10B981);
      case 'holiday':
        return const Color(0xFFEC4899);
      case 'academic':
        return const Color(0xFF0EA5E9);
      case 'exam':
      case 'examination':
        return const Color(0xFFF59E0B);
      case 'transport':
        return const Color(0xFF06B6D4);
      case 'fee':
      case 'fee & accounts':
        return const Color(0xFF14B8A6);
      case 'emergency':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return Icons.campaign_rounded;
      case 'meeting':
        return Icons.groups_rounded;
      case 'event':
        return Icons.celebration_rounded;
      case 'holiday':
        return Icons.beach_access_rounded;
      case 'academic':
        return Icons.school_rounded;
      case 'exam':
      case 'examination':
        return Icons.quiz_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'fee':
      case 'fee & accounts':
        return Icons.payments_rounded;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'normal':
        return const Color(0xFFF59E0B);
      case 'low':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(noticeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: notices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final notice = notices[idx];
        final isUrgentNotice = notice.isUrgent || notice.priority == 'urgent';
        final effectivePriority = isUrgentNotice ? 'urgent' : notice.priority;
        final catColor = _getCategoryColor(notice.category);
        final prioColor = _getPriorityColor(effectivePriority);
        final isAuthor = notice.authorId == currentUserId;
        final canEdit = isAdmin || isAuthor;

        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (c) => NoticeDetailDialog(noticeId: notice.id, userRole: userRole, currentUserId: currentUserId),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUrgentNotice
                    ? const Color(0xFFDC2626)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isUrgentNotice ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isUrgentNotice
                      ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon + Category Pill + Priority Pill + Status + 3 Dots
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isUrgentNotice
                            ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                            : catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isUrgentNotice ? Icons.campaign_rounded : _getCategoryIcon(notice.category),
                        size: 16,
                        color: isUrgentNotice ? const Color(0xFFDC2626) : catColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isUrgentNotice) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                  SizedBox(width: 1),
                                  Text(
                                    'URGENT',
                                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              notice.category,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor),
                            ),
                          ),
                          Text(
                            effectivePriority.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: prioColor),
                          ),
                          if (notice.isNewlyPublished) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ],
                          if (notice.isPinned) ...[
                            const Icon(Icons.push_pin_rounded, size: 12, color: Color(0xFFF59E0B)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(notice.status, isDark),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      onSelected: (val) {
                        if (val == 'view') {
                          showDialog(
                            context: context,
                            builder: (c) => NoticeDetailDialog(noticeId: notice.id, userRole: userRole, currentUserId: currentUserId),
                          );
                        } else if (val == 'edit') {
                          showDialog(
                            context: context,
                            builder: (c) => CreateEditNoticeDialog(editNotice: notice),
                          );
                        } else if (val == 'duplicate') {
                          notifier.duplicateNotice(notice.id);
                        } else if (val == 'archive') {
                          notifier.archiveNotice(notice.id);
                        } else if (val == 'delete') {
                          notifier.deleteNotice(notice.id);
                        } else if (val == 'ack_dashboard') {
                          showDialog(
                            context: context,
                            builder: (c) => NoticeAcknowledgementsDialog(noticeId: notice.id, title: notice.title),
                          );
                        } else if (val == 'share') {
                          Clipboard.setData(ClipboardData(text: '${notice.title}\n\n${notice.content}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notice copied to clipboard!')),
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'view', child: Text('View Details', style: TextStyle(fontSize: 12))),
                        if (notice.requiresAcknowledgement && (isAdmin || isAuthor))
                          const PopupMenuItem(value: 'ack_dashboard', child: Text('Acknowledgements', style: TextStyle(fontSize: 12, color: Color(0xFF10B981)))),
                        if (canEdit)
                          const PopupMenuItem(value: 'edit', child: Text('Edit Notice', style: TextStyle(fontSize: 12))),
                        if (canEdit)
                          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate', style: TextStyle(fontSize: 12))),
                        const PopupMenuItem(value: 'share', child: Text('Share', style: TextStyle(fontSize: 12))),
                        if (canEdit)
                          const PopupMenuItem(value: 'archive', child: Text('Archive', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B)))),
                        if (canEdit)
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  notice.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),

                // Snippet
                Text(
                  notice.content.replaceAll(RegExp(r'<[^>]*>'), ''),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Attachments indicator
                if (notice.attachments.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.attach_file_rounded, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        '${notice.attachments.length} Attachment${notice.attachments.length > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                const Divider(height: 1),
                const SizedBox(height: 8),

                // Bottom Row: Date & Engagement Stats + View Button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.publishedAt != null
                                ? df.format(notice.publishedAt!.toLocal())
                                : 'Created ${df.format(notice.createdAt.toLocal())}',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Text('${notice.viewCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              if (notice.requiresAcknowledgement) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.check_circle_outline_rounded, size: 12, color: const Color(0xFF10B981)),
                                const SizedBox(width: 3),
                                Text(
                                  '${notice.ackCount} (${notice.ackPercentage.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => NoticeDetailDialog(noticeId: notice.id, userRole: userRole, currentUserId: currentUserId),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(60, 30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'published':
        bg = const Color(0xFF10B981).withOpacity(0.12);
        fg = const Color(0xFF10B981);
        break;
      case 'scheduled':
        bg = const Color(0xFF0EA5E9).withOpacity(0.12);
        fg = const Color(0xFF0EA5E9);
        break;
      case 'draft':
        bg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        break;
      case 'pending_approval':
        bg = const Color(0xFFF59E0B).withOpacity(0.12);
        fg = const Color(0xFFF59E0B);
        label = 'PENDING';
        break;
      case 'expired':
        bg = const Color(0xFFEF4444).withOpacity(0.12);
        fg = const Color(0xFFEF4444);
        break;
      case 'archived':
        bg = const Color(0xFF6B7280).withOpacity(0.12);
        fg = const Color(0xFF6B7280);
        break;
      default:
        bg = const Color(0xFF64748B).withOpacity(0.12);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}
