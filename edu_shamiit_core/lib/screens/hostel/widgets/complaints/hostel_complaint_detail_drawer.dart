import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../utils/download_helper.dart';
import '../../providers/hostel_provider.dart';
import '../../models/hostel_complaint_models.dart';
import 'dialogs/assign_complaint_dialog.dart';
import 'dialogs/update_status_dialog.dart';
import 'dialogs/complaint_feedback_dialog.dart';

class HostelComplaintDetailDrawer extends ConsumerStatefulWidget {
  const HostelComplaintDetailDrawer({super.key});

  @override
  ConsumerState<HostelComplaintDetailDrawer> createState() => _HostelComplaintDetailDrawerState();
}

class _HostelComplaintDetailDrawerState extends ConsumerState<HostelComplaintDetailDrawer> {
  final TextEditingController _commentController = TextEditingController();
  bool _isInternalNote = false;
  bool _isUploadingAttachment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detail = state.selectedComplaintDetail;
    final c = detail?.complaint;

    if (c == null) {
      return Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    final commentsCount = detail?.comments.length ?? 0;
    final attachmentsCount = c.attachments.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final drawerWidth = screenWidth > 500 ? 460.0 : (screenWidth * 0.95).clamp(300.0, 460.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteHeight = constraints.maxHeight.isFinite;

        return Container(
          width: drawerWidth,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 16,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header: "Complaint Details" [X]
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Complaint Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: () => notifier.closeComplaintDrawer(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF64748B),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. Hero Banner: Thumbnail + Status/Priority Badges + Title + No + Date
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          c.thumbnailUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderPhoto(isDark),
                        )
                      : _buildPlaceholderPhoto(isDark),
                ),
                const SizedBox(width: 14),
                // Title and Meta Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row (Open / High Priority / Feedback Rating)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusPill(c.status),
                          _buildPriorityPill(c.priority),
                          if (detail?.feedback != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFD97706)),
                                  const SizedBox(width: 3),
                                  Text(
                                    detail!.feedback!.averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Title
                      Text(
                        c.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Complaint No
                      Text(
                        'Complaint No: ${c.complaintNumber}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Raised on
                      Text(
                        'Raised on: ${c.raisedOnFormatted.replaceAll('\n', ', ')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Four Tabs: Overview, Updates (3), Assign & Resolve, Attachments (2)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildDrawerTabItem('Overview', 0, state.complaintDrawerTab, notifier, isDark),
                _buildDrawerTabItem('Updates ($commentsCount)', 1, state.complaintDrawerTab, notifier, isDark),
                _buildDrawerTabItem('Assign & Resolve', 2, state.complaintDrawerTab, notifier, isDark),
                _buildDrawerTabItem('Attachments ($attachmentsCount)', 3, state.complaintDrawerTab, notifier, isDark),
              ],
            ),
          ),

          // 4. Tab Body Content with responsive scrollable height
          if (hasFiniteHeight)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _buildTabContent(context, state, c, detail, isDark, notifier),
              ),
            )
          else
            SizedBox(
              height: (screenHeight - 260).clamp(320.0, 650.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: _buildTabContent(context, state, c, detail, isDark, notifier),
              ),
            ),

          // 5. Sticky Bottom Action Buttons (Update Status, Assign, More)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                // Green "Update Status" Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => UpdateComplaintStatusDialog(complaint: c),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Update Status',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Blue "Assign" Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AssignComplaintDialog(
                          complaintId: c.id,
                          currentAssignee: c.primaryAssigneeName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_rounded, size: 16, color: Colors.white),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Assign',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Ellipsis popup for Reopen, Complete, Rating, Cancel
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.more_horiz_rounded, size: 18, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                  onSelected: (action) {
                    if (action == 'COMPLETE') {
                      notifier.completeComplaint(c.id);
                    } else if (action == 'REOPEN') {
                      notifier.reopenComplaint(c.id);
                    } else if (action == 'FEEDBACK') {
                      showDialog(
                        context: context,
                        builder: (ctx) => ComplaintFeedbackDialog(
                          complaintId: c.id,
                          complaintTitle: c.title,
                          initialRating: detail?.feedback?.rating,
                          initialQuality: detail?.feedback?.resolutionQuality,
                          initialResponseTime: detail?.feedback?.responseTimeRating,
                          initialStaffBehavior: detail?.feedback?.staffBehaviorRating,
                          initialComment: detail?.feedback?.comment,
                          initialIsSatisfied: detail?.feedback?.isSatisfied,
                        ),
                      );
                    } else if (action == 'CANCEL') {
                      notifier.cancelComplaint(c.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'COMPLETE', child: Text('Formally Complete')),
                    const PopupMenuItem(value: 'REOPEN', child: Text('Reopen Complaint')),
                    const PopupMenuItem(value: 'FEEDBACK', child: Text('Resident Rating & Feedback')),
                    const PopupMenuItem(value: 'CANCEL', child: Text('Cancel Complaint')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
  }

  Widget _buildDrawerTabItem(
    String label,
    int index,
    int activeIndex,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final isSelected = index == activeIndex;
    return Expanded(
      child: InkWell(
        onTap: () => notifier.setComplaintDrawerTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    HostelState state,
    HostelComplaintItem c,
    HostelComplaintDetail360? detail,
    bool isDark,
    HostelNotifier notifier,
  ) {
    switch (state.complaintDrawerTab) {
      case 1:
        return _buildUpdatesTab(detail?.comments ?? [], c.id, notifier, isDark);
      case 2:
        return _buildAssignAndResolveTab(context, c, detail, notifier, isDark);
      case 3:
        return _buildAttachmentsTab(context, c, notifier, isDark);
      default:
        return _buildOverviewTab(context, c, detail?.feedback, detail?.history ?? [], isDark);
    }
  }

  // --- TAB 0: OVERVIEW MATCHING SCREENSHOT ---
  Widget _buildOverviewTab(
    BuildContext context,
    HostelComplaintItem c,
    ComplaintFeedbackItem? feedback,
    List<ComplaintHistoryItem> history,
    bool isDark,
  ) {
    final resolutionDue = c.resolutionDueAt != null
        ? DateFormat('dd MMM yyyy').format(c.resolutionDueAt!)
        : '14 May 2024';
    final lastUpdated = DateFormat('dd MMM yyyy, hh:mm a').format(c.updatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Key-Value Metadata List
        _buildMetaRow(Icons.category_outlined, 'Category', c.category, isDark),
        _buildMetaRow(Icons.apartment_outlined, 'Hostel', c.hostelName, isDark),
        _buildMetaRow(Icons.door_front_door_outlined, 'Room No.', c.roomNumber ?? 'A-101', isDark),
        _buildMetaRow(
          Icons.person_outline_rounded,
          'Reported By',
          '${c.reportedByName} (${c.reportedByClass ?? "Class 10 A"})',
          isDark,
        ),
        _buildMetaRow(Icons.description_outlined, 'Description', c.description, isDark, isMultiLine: true),

        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        _buildMetaRow(Icons.schedule_outlined, 'Status', c.status, isDark, isStatus: true),
        _buildMetaRow(Icons.flag_outlined, 'Priority', c.priority, isDark, isPriority: true),
        _buildMetaRow(
          Icons.engineering_outlined,
          'Assigned To',
          c.primaryAssigneeName != null ? '${c.primaryAssigneeName} (${c.primaryAssigneeRole ?? "Maintenance Staff"})' : 'Unassigned',
          isDark,
        ),
        _buildMetaRow(Icons.event_outlined, 'Expected Resolution', resolutionDue, isDark),
        _buildMetaRow(Icons.update_outlined, 'Last Updated', lastUpdated, isDark),

        // RESIDENT FEEDBACK SECTION
        if (feedback != null) ...[
          const SizedBox(height: 16),
          _buildFeedbackSummaryCard(context, c, feedback, isDark),
        ] else if (c.status == 'COMPLETED' || c.status == 'RESOLVED') ...[
          const SizedBox(height: 16),
          _buildPromptFeedbackCard(context, c, isDark),
        ],

        const SizedBox(height: 20),

        // Timeline Section
        Text(
          'Timeline',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        if (history.isEmpty)
          // Fallback realistic timeline events matching screenshot
          _buildTimelineFallback(isDark)
        else
          Column(
            children: List.generate(history.length, (i) {
              final h = history[i];
              final isLast = i == history.length - 1;
              String displayTitle = h.eventTitle.replaceAll('???', '\u2605');
              if (displayTitle.toLowerCase().contains('submitted feedback') && feedback != null) {
                displayTitle = 'Requester submitted feedback (${feedback.averageRating.toStringAsFixed(1)} \u2605)';
              }
              return _buildTimelineItem(
                title: displayTitle,
                subtitle: '${h.timeFormatted} by ${h.actorName}',
                note: h.actionNote,
                isCompleted: true,
                isLast: isLast,
                isDark: isDark,
              );
            }),
          ),
      ],
    );
  }

  Widget _buildTimelineFallback(bool isDark) {
    return Column(
      children: [
        _buildTimelineItem(
          title: 'Complaint raised',
          subtitle: '12 May 2024, 10:30 AM by Rahul Sharma',
          isCompleted: true,
          isLast: false,
          isDark: isDark,
        ),
        _buildTimelineItem(
          title: 'Assigned to Mr. Ramesh',
          subtitle: '12 May 2024, 11:00 AM by Hostel Administrator',
          isCompleted: true,
          isLast: false,
          isDark: isDark,
        ),
        _buildTimelineItem(
          title: 'In progress',
          subtitle: '12 May 2024, 02:15 PM',
          note: 'Ramesh: Spare part ordered, will fix by tomorrow.',
          isCompleted: true,
          isLast: false,
          isDark: isDark,
        ),
        _buildTimelineItem(
          title: 'Pending student confirmation',
          subtitle: 'Awaiting confirmation after resolution',
          isCompleted: false,
          isLast: true,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    String? note,
    required bool isCompleted,
    required bool isLast,
    required bool isDark,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connector line drawn behind dots
        if (!isLast)
          Positioned(
            top: 8,
            bottom: -8,
            left: 5,
            child: Container(
              width: 2,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator dot
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Event Text (unconstrained height to guarantee 0 overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isMultiLine = false,
    bool isStatus = false,
    bool isPriority = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF94A3B8))),
          Expanded(
            child: isStatus
                ? Align(alignment: Alignment.centerLeft, child: _buildStatusPill(value))
                : isPriority
                    ? Align(alignment: Alignment.centerLeft, child: _buildPriorityPill(value))
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

    Widget _buildFeedbackSummaryCard(
    BuildContext context,
    HostelComplaintItem c,
    ComplaintFeedbackItem feedback,
    bool isDark,
  ) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resident Resolution Feedback',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 3),
                    Text(
                      '${feedback.averageRating.toStringAsFixed(1)} ★',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ComplaintFeedbackDialog(
                      complaintId: c.id,
                      complaintTitle: c.title,
                      initialRating: feedback.rating,
                      initialQuality: feedback.resolutionQuality,
                      initialResponseTime: feedback.responseTimeRating,
                      initialStaffBehavior: feedback.staffBehaviorRating,
                      initialComment: feedback.comment,
                      initialIsSatisfied: feedback.isSatisfied,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: feedback.isSatisfied
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      feedback.isSatisfied ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                      size: 13,
                      color: feedback.isSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      feedback.isSatisfied ? 'Resident Satisfied' : 'Resident Unsatisfied',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: feedback.isSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              if (feedback.submittedByName != null) ...[
                const SizedBox(width: 8),
                Text(
                  'by ${feedback.submittedByName!}',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (feedback.resolutionQuality != null)
                _buildAspectChip('Quality', feedback.resolutionQuality!, isDark),
              if (feedback.responseTimeRating != null)
                _buildAspectChip('Response Time', feedback.responseTimeRating!, isDark),
              if (feedback.staffBehaviorRating != null)
                _buildAspectChip('Staff Behavior', feedback.staffBehaviorRating!, isDark),
            ],
          ),
          if (feedback.comment != null && feedback.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, size: 16, color: textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feedback.comment!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptFeedbackCard(
    BuildContext context,
    HostelComplaintItem c,
    bool isDark,
  ) {
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.star_outline_rounded, size: 18, color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate Resolution Service',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                Text(
                  'Share resident feedback & ratings for this completed ticket.',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => ComplaintFeedbackDialog(
                  complaintId: c.id,
                  complaintTitle: c.title,
                ),
              );
            },
            icon: const Icon(Icons.star_rounded, size: 14, color: Colors.white),
            label: const Text('Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectChip(String label, int rating, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          ...List.generate(
            5,
            (idx) => Icon(
              idx < rating ? Icons.star_rounded : Icons.star_border_rounded,
              size: 12,
              color: idx < rating ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: UPDATES & DISCUSSION ---
  Widget _buildUpdatesTab(
    List<ComplaintCommentItem> comments,
    String complaintId,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add Comment Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _commentController,
                maxLines: 2,
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Type an update or internal note...',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Internal Note Toggle Checkbox
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isInternalNote,
                        onChanged: (val) => setState(() => _isInternalNote = val ?? false),
                      ),
                      Text(
                        'Internal Staff Note',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      final msg = _commentController.text.trim();
                      if (msg.isNotEmpty) {
                        notifier.addComplaintComment(
                          complaintId,
                          msg,
                          type: _isInternalNote ? 'INTERNAL_NOTE' : 'PUBLIC_UPDATE',
                        );
                        _commentController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Post', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Comments List
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No updates yet. Post the first comment above.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          Column(
            children: comments.map((cm) {
              final isInternal = cm.commentType == 'INTERNAL_NOTE';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInternal
                      ? (isDark ? const Color(0xFF452B14) : const Color(0xFFFEF3C7))
                      : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isInternal
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cm.authorName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isInternal)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Internal Note',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          cm.timeFormatted,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cm.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // --- TAB 2: ASSIGN & RESOLVE ---
  Widget _buildAssignAndResolveTab(
    BuildContext context,
    HostelComplaintItem c,
    HostelComplaintDetail360? detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Assignment Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Assignee',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, size: 28, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.primaryAssigneeName ?? 'Not Assigned',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          c.primaryAssigneeRole ?? 'Maintenance Staff',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AssignComplaintDialog(complaintId: c.id, currentAssignee: c.primaryAssigneeName),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Reassign', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Resolution Workflow Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resolution Workflow',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              if (c.status == 'RESOLVED' || c.status == 'COMPLETED') ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.resolutionSummary ?? 'Issue resolved and verified.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'Once the technician inspects and fixes the reported issue, mark complaint as resolved to notify student.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => UpdateComplaintStatusDialog(complaint: c, initialStatus: 'RESOLVED'),
                    );
                  },
                  icon: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                  label: const Text('Mark Resolved with Work Summary', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: ATTACHMENTS ---
  Widget _buildAttachmentsTab(
    BuildContext context,
    HostelComplaintItem c,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments & Photos (${c.attachments.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (_isUploadingAttachment)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      withData: true,
                    );
                    if (result == null || result.files.isEmpty) return;
                    final file = result.files.first;
                    final bytes = file.bytes;
                    if (bytes == null || bytes.isEmpty) return;

                    setState(() => _isUploadingAttachment = true);
                    await notifier.uploadComplaintAttachmentForComplaint(c.id, bytes, file.name);
                    if (mounted) setState(() => _isUploadingAttachment = false);
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isUploadingAttachment = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error uploading attachment: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                label: const Text('Upload Document', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty) ...[
          Text('Primary Evidence Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              c.thumbnailUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholderPhoto(isDark),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (c.attachments.isEmpty && (c.thumbnailUrl == null || c.thumbnailUrl!.isEmpty))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attachment_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No Attachments Uploaded',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "Upload Document" above to attach supporting files or photos.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...c.attachments.map((att) {
            final rawName = att is Map ? att['name'] ?? 'Evidence_File.jpg' : att.toString();
            final url = att is Map ? att['url'] ?? '' : (rawName.startsWith('http') ? rawName : '');
            final displayName = rawName.contains('/') ? rawName.split('/').last : rawName;
            final lower = displayName.toLowerCase();
            final isPdf = lower.endsWith('.pdf');
            final isImage = lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
            final isDoc = lower.endsWith('.doc') || lower.endsWith('.docx');
            final docIcon = isPdf
                ? Icons.picture_as_pdf_rounded
                : isImage
                    ? Icons.image_rounded
                    : isDoc
                        ? Icons.description_rounded
                        : Icons.insert_drive_file_rounded;
            final iconColor = isPdf
                ? const Color(0xFFDC2626)
                : isImage
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF0D9488);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(docIcon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isPdf ? 'PDF Document' : (isImage ? 'Photo Evidence' : 'Document File'),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                    splashRadius: 16,
                    tooltip: 'Download',
                    onPressed: () async {
                      if (url.isNotEmpty && url.startsWith('http')) {
                        getDownloadHelper().downloadFile(url, displayName);
                      } else {
                        final bytes = Uint8List.fromList(utf8.encode(
                          'EDUSHAMIIT - COMPLAINT ATTACHMENT\nComplaint: ${c.complaintNumber}\nFile: $displayName\n'
                        ));
                        await getDownloadHelper().downloadBytes(bytes, displayName);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloading $displayName...'),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPlaceholderPhoto(bool isDark) {
    return Container(
      width: 72,
      height: 72,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      child: const Icon(Icons.broken_image_rounded, size: 32, color: Color(0xFF94A3B8)),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'NEW':
      case 'OPEN':
      case 'ACTIVE':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Open';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
        label = 'In Progress';
        break;
      case 'RESOLVED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Resolved';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildPriorityPill(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$priority Priority',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
      ),
    );
  }
}
