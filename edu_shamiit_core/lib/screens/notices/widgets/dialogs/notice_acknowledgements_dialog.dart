import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/notice_models.dart';
import '../../providers/notice_provider.dart';

class NoticeAcknowledgementsDialog extends ConsumerStatefulWidget {
  final String noticeId;
  final String title;

  const NoticeAcknowledgementsDialog({
    super.key,
    required this.noticeId,
    required this.title,
  });

  @override
  ConsumerState<NoticeAcknowledgementsDialog> createState() => _NoticeAcknowledgementsDialogState();
}

class _NoticeAcknowledgementsDialogState extends ConsumerState<NoticeAcknowledgementsDialog> {
  bool _isLoading = true;
  List<NoticeRecipientModel> _recipients = [];
  Map<String, dynamic> _summary = {};
  String _search = '';
  String _selectedStatus = 'All';
  int _page = 1;
  int _pageSize = 20;
  bool _isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(noticeApiServiceProvider);
      final res = await api.getAcknowledgements(
        widget.noticeId,
        search: _search,
        status: _selectedStatus == 'All' ? '' : _selectedStatus.toLowerCase(),
        page: _page,
        pageSize: _pageSize,
      );
      setState(() {
        _recipients = res['recipients'] as List<NoticeRecipientModel>;
        _summary = res['summary'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRemindPending() async {
    setState(() => _isSendingReminder = true);
    try {
      final api = ref.read(noticeApiServiceProvider);
      final res = await api.remindPendingRecipients(widget.noticeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Reminders queued!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final df = DateFormat('dd MMM, hh:mm a');

    final total = _summary['total_recipients'] ?? _recipients.length;
    final ack = _summary['acknowledged'] ?? _recipients.where((r) => r.isAcknowledged).length;
    final pending = _summary['pending'] ?? (total - ack);
    final pct = total > 0 ? (ack / total * 100).toStringAsFixed(1) : '0';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 840,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.how_to_reg_rounded, size: 20, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipient Acknowledgements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.title,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Summary Stats Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildMiniMetric('Total Targets', '$total', isDark),
                      const SizedBox(width: 20),
                      _buildMiniMetric('Acknowledged', '$ack ($pct%)', isDark, color: const Color(0xFF10B981)),
                      const SizedBox(width: 20),
                      _buildMiniMetric('Pending', '$pending', isDark, color: const Color(0xFFF59E0B)),
                    ],
                  ),
                  if (pending > 0)
                    ElevatedButton.icon(
                      onPressed: _isSendingReminder ? null : _handleRemindPending,
                      icon: const Icon(Icons.notifications_active_rounded, size: 14),
                      label: const Text('Remind Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
            ),

            // Search & Filter Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        onChanged: (val) {
                          _search = val.trim();
                          _fetchData();
                        },
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search recipient name or class...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter by status
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _fetchData();
                          }
                        },
                        items: const ['All', 'Acknowledged', 'Pending', 'Declined'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Recipients Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recipients.isEmpty
                      ? const Center(child: Text('No recipient records found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _recipients.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final r = _recipients[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                child: Text(
                                  r.fullName.isNotEmpty ? r.fullName[0].toUpperCase() : 'U',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                              title: Text(
                                r.fullName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              subtitle: Text(
                                '${r.role.toUpperCase()} ${r.className != null ? "• ${r.className}" : ""}',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: r.isAcknowledged
                                          ? const Color(0xFF10B981).withOpacity(0.12)
                                          : (r.acknowledgementStatus == 'declined'
                                              ? const Color(0xFFEF4444).withOpacity(0.12)
                                              : const Color(0xFFF59E0B).withOpacity(0.12)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.acknowledgementStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: r.isAcknowledged
                                            ? const Color(0xFF10B981)
                                            : (r.acknowledgementStatus == 'declined' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                                      ),
                                    ),
                                  ),
                                  if (r.acknowledgedAt != null)
                                    Text(df.format(r.acknowledgedAt!.toLocal()), style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)))),
      ],
    );
  }
}
