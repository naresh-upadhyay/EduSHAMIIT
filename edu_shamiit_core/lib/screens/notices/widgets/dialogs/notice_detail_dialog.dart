import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/notice_models.dart';
import '../../providers/notice_provider.dart';
import 'create_edit_notice_dialog.dart';
import 'notice_acknowledgements_dialog.dart';

class NoticeDetailDialog extends ConsumerStatefulWidget {
  final String noticeId;
  final String userRole;
  final String currentUserId;

  const NoticeDetailDialog({
    super.key,
    required this.noticeId,
    required this.userRole,
    required this.currentUserId,
  });

  @override
  ConsumerState<NoticeDetailDialog> createState() => _NoticeDetailDialogState();
}

class _NoticeDetailDialogState extends ConsumerState<NoticeDetailDialog> {
  NoticeModel? _notice;
  bool _isLoading = true;
  String? _error;
  bool _isAcknowledging = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(noticeApiServiceProvider);
      final notice = await api.getNoticeDetail(widget.noticeId);
      setState(() {
        _notice = notice;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAcknowledge({String status = 'acknowledged'}) async {
    setState(() => _isAcknowledging = true);
    try {
      final api = ref.read(noticeApiServiceProvider);
      await api.acknowledgeNotice(widget.noticeId, status: status);
      await ref.read(noticeProvider.notifier).refreshAll();
      await _loadDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice ${status == "acknowledged" ? "acknowledged" : "declined"} successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcknowledging = false);
    }
  }

  bool get isAdmin {
    final r = widget.userRole.toLowerCase();
    return r == 'super_admin' || r == 'admin' || r == 'principal' || r == 'vice_principal' || r == 'director';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: _isLoading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Failed to load notice: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadDetail, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _buildContent(context, _notice!, isDark, df),
      ),
    );
  }

  Widget _buildContent(BuildContext context, NoticeModel notice, bool isDark, DateFormat df) {
    final isAuthor = notice.authorId == widget.currentUserId;
    final canManage = isAdmin || isAuthor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notice.category.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                ),
              ),
              if (notice.isUrgent || notice.priority == 'urgent') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'URGENT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Title
              Text(
                notice.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Author & Published Date Metadata
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    child: Text(
                      (notice.authorName ?? 'A')[0].toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.authorName ?? 'Admin / Institute',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Text(
                        notice.publishedAt != null
                            ? 'Published on ${df.format(notice.publishedAt!.toLocal())}'
                            : 'Created on ${df.format(notice.createdAt.toLocal())}',
                        style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Content Body
              SelectableText(
                notice.content,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 20),

              // Attachments Section
              if (notice.attachments.isNotEmpty) ...[
                Text(
                  'Attachments (${notice.attachments.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                ...notice.attachments.map((att) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            att.name,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (att.formattedSize.isNotEmpty)
                          Text(att.formattedSize, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF4F46E5)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: att.url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Attachment link copied to clipboard!')),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Acknowledgement Status Banner
              if (notice.requiresAcknowledgement) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: notice.userIsAcknowledged
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: notice.userIsAcknowledged
                          ? const Color(0xFF10B981).withOpacity(0.3)
                          : const Color(0xFFF59E0B).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        notice.userIsAcknowledged ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: notice.userIsAcknowledged ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notice.userIsAcknowledged
                              ? 'You acknowledged this notice.'
                              : 'This notice requires your acknowledgement of receipt.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: notice.userIsAcknowledged ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      if (!notice.userIsAcknowledged)
                        ElevatedButton.icon(
                          onPressed: _isAcknowledging ? null : () => _handleAcknowledge(),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Acknowledge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(60, 32),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Management Stats (For Admin / Author)
              if (canManage) ...[
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
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('${notice.viewCount} views', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          if (notice.requiresAcknowledgement) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.check_circle_outline_rounded, size: 14, color: const Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text('${notice.ackCount} acknowledged (${notice.ackPercentage.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                          ],
                        ],
                      ),
                      if (notice.requiresAcknowledgement)
                        TextButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => NoticeAcknowledgementsDialog(noticeId: notice.id, title: notice.title),
                            );
                          },
                          icon: const Icon(Icons.how_to_reg_rounded, size: 14),
                          label: const Text('Dashboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${notice.title}\n\n${notice.content}'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice text copied!')));
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Text', style: TextStyle(fontSize: 11)),
              ),
              Row(
                children: [
                  if (canManage)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showDialog(
                          context: context,
                          builder: (ctx) => CreateEditNoticeDialog(editNotice: notice),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
