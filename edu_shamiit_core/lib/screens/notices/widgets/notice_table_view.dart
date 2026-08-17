import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/notice_models.dart';
import '../providers/notice_provider.dart';
import 'dialogs/create_edit_notice_dialog.dart';
import 'dialogs/notice_detail_dialog.dart';
import 'dialogs/notice_acknowledgements_dialog.dart';

class NoticeTableView extends ConsumerWidget {
  final List<NoticeModel> notices;
  final String userRole;
  final String currentUserId;

  const NoticeTableView({
    super.key,
    required this.notices,
    required this.userRole,
    required this.currentUserId,
  });

  bool get isAdmin {
    final r = userRole.toLowerCase();
    return r == 'super_admin' || r == 'admin' || r == 'principal' || r == 'vice_principal' || r == 'director';
  }

  bool get isStaff {
    final r = userRole.toLowerCase();
    return r == 'teacher' || r == 'class_teacher' || r == 'transport_manager' || r == 'accountant' || r == 'hr' || r == 'librarian';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return const Color(0xFFF97316); // Orange
      case 'meeting':
        return const Color(0xFF8B5CF6); // Purple
      case 'event':
        return const Color(0xFF10B981); // Emerald
      case 'holiday':
        return const Color(0xFFEC4899); // Pink
      case 'academic':
        return const Color(0xFF0EA5E9); // Sky
      case 'exam':
      case 'examination':
        return const Color(0xFFF59E0B); // Amber
      case 'transport':
        return const Color(0xFF06B6D4); // Cyan
      case 'fee':
      case 'fee & accounts':
        return const Color(0xFF14B8A6); // Teal
      case 'emergency':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate
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

  String _formatAudienceText(NoticeModel notice) {
    if (notice.targetScope == 'entire_institute') return 'Entire School';
    if (notice.targetRoles.isNotEmpty) {
      final roleNames = notice.targetRoles.map((r) => r[0].toUpperCase() + r.substring(1)).join(', ');
      if (notice.targetClasses.isNotEmpty) {
        return '$roleNames + ${notice.targetClasses.length} Classes';
      }
      return roleNames;
    }
    if (notice.targetClasses.isNotEmpty) {
      final first = notice.targetClasses.first;
      final rest = notice.targetClasses.length - 1;
      return rest > 0 ? '$first + $rest more' : first;
    }
    if (notice.targetUserIds.isNotEmpty) {
      return '${notice.targetUserIds.length} Recipients';
    }
    return 'All Members';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noticeProvider);
    final notifier = ref.read(noticeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    final allSelected = notices.isNotEmpty && notices.every((n) => state.selectedNoticeIds.contains(n.id));

    return LayoutBuilder(
      builder: (context, constraints) {
        const double tableMinWidth = 1060.0;
        final double effectiveWidth = constraints.maxWidth > tableMinWidth ? constraints.maxWidth : tableMinWidth;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: effectiveWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. TABLE HEADER ---
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Selection Checkbox
                          SizedBox(
                            width: 44,
                            child: Checkbox(
                              value: allSelected,
                              onChanged: (val) => notifier.selectAllNotices(val == true),
                              activeColor: const Color(0xFF4F46E5),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          // Title & Content
                          const Expanded(
                            flex: 30,
                            child: Text(
                              'Title & Content',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Audience
                          const Expanded(
                            flex: 14,
                            child: Text(
                              'Audience',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Category
                          const Expanded(
                            flex: 13,
                            child: Text(
                              'Category',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Priority
                          const Expanded(
                            flex: 10,
                            child: Text(
                              'Priority',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Published / Status
                          const Expanded(
                            flex: 16,
                            child: Text(
                              'Published / Status',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Engagement
                          const Expanded(
                            flex: 12,
                            child: Text(
                              'Engagement',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                          // Actions
                          const SizedBox(
                            width: 90,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 2. TABLE BODY ROWS ---
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notices.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final isSelected = state.selectedNoticeIds.contains(notice.id);
                        final catColor = _getCategoryColor(notice.category);
                        final isUrgentNotice = notice.isUrgent || notice.priority == 'urgent';
                        final effectivePriority = isUrgentNotice ? 'urgent' : notice.priority;
                        final prioColor = _getPriorityColor(effectivePriority);
                        final isAuthor = notice.authorId == currentUserId;
                        final canEdit = isAdmin || isAuthor;

                        return Material(
                          color: isSelected
                              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFEEF2FF))
                              : (isUrgentNotice
                                  ? (isDark ? const Color(0xFFDC2626).withValues(alpha: 0.06) : const Color(0xFFFEF2F2))
                                  : Colors.transparent),
                          child: InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => NoticeDetailDialog(
                                  noticeId: notice.id,
                                  userRole: userRole,
                                  currentUserId: currentUserId,
                                ),
                              );
                            },
                            hoverColor: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: isUrgentNotice
                                  ? const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Color(0xFFDC2626),
                                          width: 3.5,
                                        ),
                                      ),
                                    )
                                  : null,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Selection Checkbox
                                  SizedBox(
                                    width: 36,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (val) => notifier.toggleNoticeSelection(notice.id),
                                      activeColor: const Color(0xFF4F46E5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),

                                  // Title & Content
                                  Expanded(
                                    flex: 30,
                                    child: Row(
                                      children: [
                                        // Category Icon Container
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isUrgentNotice
                                                ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                                                : catColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isUrgentNotice ? Icons.campaign_rounded : _getCategoryIcon(notice.category),
                                            size: 18,
                                            color: isUrgentNotice ? const Color(0xFFDC2626) : catColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Title, Badges & Snippet
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      notice.title,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isUrgentNotice) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDC2626),
                                                        borderRadius: BorderRadius.circular(4),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                                                          SizedBox(width: 1),
                                                          Text(
                                                            'URGENT',
                                                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  if (notice.isNewlyPublished) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEF4444),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text(
                                                        'New',
                                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                                      ),
                                                    ),
                                                  ],
                                                  if (notice.isPinned) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.push_pin_rounded, size: 13, color: Color(0xFFF59E0B)),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                notice.content.replaceAll(RegExp(r'<[^>]*>'), ''),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (notice.attachments.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.attach_file_rounded, size: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${notice.attachments.length} Attachment${notice.attachments.length > 1 ? "s" : ""}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Audience
                                  Expanded(
                                    flex: 14,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        _formatAudienceText(notice),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),

                                  // Category Pill
                                  Expanded(
                                    flex: 13,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: catColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          notice.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: catColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Priority Pill
                                  Expanded(
                                    flex: 10,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: prioColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          effectivePriority.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: prioColor,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Published / Status
                                  Expanded(
                                    flex: 16,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (notice.publishedAt != null)
                                          Text(
                                            df.format(notice.publishedAt!.toLocal()),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else if (notice.scheduledAt != null)
                                          Text(
                                            'Sched: ${df.format(notice.scheduledAt!.toLocal())}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0EA5E9),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else
                                          Text(
                                            'Created: ${df.format(notice.createdAt.toLocal())}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 3),
                                        _buildStatusBadge(notice.status, isDark),
                                      ],
                                    ),
                                  ),

                                  // Engagement
                                  Expanded(
                                    flex: 12,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${notice.viewCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (notice.requiresAcknowledgement) ...[
                                          const SizedBox(height: 3),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_outline_rounded, size: 13, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${notice.ackCount} (${notice.ackPercentage.toStringAsFixed(0)}%)',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Actions
                                  SizedBox(
                                    width: 90,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // View Button
                                        OutlinedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => NoticeDetailDialog(
                                                noticeId: notice.id,
                                                userRole: userRole,
                                                currentUserId: currentUserId,
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: const Size(48, 28),
                                            side: BorderSide(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                            ),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          child: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 2),

                                        // Popup Menu Action
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          onSelected: (val) {
                                            if (val == 'view') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => NoticeDetailDialog(
                                                  noticeId: notice.id,
                                                  userRole: userRole,
                                                  currentUserId: currentUserId,
                                                ),
                                              );
                                            } else if (val == 'edit') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => CreateEditNoticeDialog(editNotice: notice),
                                              );
                                            } else if (val == 'duplicate') {
                                              notifier.duplicateNotice(notice.id);
                                            } else if (val == 'archive') {
                                              notifier.archiveNotice(notice.id);
                                            } else if (val == 'delete') {
                                              notifier.deleteNotice(notice.id);
                                            } else if (val == 'pin') {
                                              notifier.updateNotice(notice.id, {'is_pinned': !notice.isPinned});
                                            } else if (val == 'copy_link') {
                                              Clipboard.setData(ClipboardData(text: 'https://app.edushamiit.com/notices/${notice.id}'));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Notice link copied to clipboard')),
                                              );
                                            } else if (val == 'acknowledgements') {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => NoticeAcknowledgementsDialog(
                                                  noticeId: notice.id,
                                                  title: notice.title,
                                                ),
                                              );
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF4F46E5)),
                                                  SizedBox(width: 8),
                                                  Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            if (notice.requiresAcknowledgement && (isAdmin || isAuthor))
                                              const PopupMenuItem(
                                                value: 'acknowledgements',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF10B981)),
                                                    SizedBox(width: 8),
                                                    Text('Acknowledgements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            if (canEdit)
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0EA5E9)),
                                                    SizedBox(width: 8),
                                                    Text('Edit Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            if (canEdit)
                                              const PopupMenuItem(
                                                value: 'pin',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.push_pin_outlined, size: 16, color: Color(0xFFF59E0B)),
                                                    SizedBox(width: 8),
                                                    Text('Pin to Top', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              ),
                                            const PopupMenuItem(
                                              value: 'duplicate',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.copy_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                                  SizedBox(width: 8),
                                                  Text('Duplicate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'copy_link',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.link_rounded, size: 16, color: Color(0xFF06B6D4)),
                                                  SizedBox(width: 8),
                                                  Text('Copy Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            if (isAdmin || isAuthor) ...[
                                              const PopupMenuDivider(),
                                              const PopupMenuItem(
                                                value: 'archive',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.archive_outlined, size: 16, color: Color(0xFFF97316)),
                                                    SizedBox(width: 8),
                                                    Text('Archive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                                    SizedBox(width: 8),
                                                    Text('Delete Notice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'published':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        label = 'PUBLISHED';
        break;
      case 'scheduled':
        bg = const Color(0xFF0EA5E9).withValues(alpha: 0.12);
        fg = const Color(0xFF0EA5E9);
        label = 'SCHEDULED';
        break;
      case 'draft':
        bg = const Color(0xFF64748B).withValues(alpha: 0.12);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        label = 'DRAFT';
        break;
      case 'pending_approval':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        label = 'PENDING';
        break;
      case 'expired':
        bg = const Color(0xFFDC2626).withValues(alpha: 0.12);
        fg = const Color(0xFFDC2626);
        label = 'EXPIRED';
        break;
      case 'archived':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        fg = const Color(0xFF8B5CF6);
        label = 'ARCHIVED';
        break;
      default:
        bg = const Color(0xFF64748B).withValues(alpha: 0.12);
        fg = const Color(0xFF64748B);
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
