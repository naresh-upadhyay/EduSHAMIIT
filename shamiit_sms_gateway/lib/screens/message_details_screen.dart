import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class MessageDetailsScreen extends StatefulWidget {
  final String messageUuid;
  final SmsMessageRecord? initialRecord;

  const MessageDetailsScreen({
    super.key,
    required this.messageUuid,
    this.initialRecord,
  });

  @override
  State<MessageDetailsScreen> createState() => _MessageDetailsScreenState();
}

class _MessageDetailsScreenState extends State<MessageDetailsScreen> {
  SmsMessageRecord? _record;
  List<SmsEventRecord> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().getMessageDetails(widget.messageUuid);
      if (!mounted) return;
      setState(() {
        if (res['message'] is Map) {
          _record = SmsMessageRecord.fromMap(Map<String, dynamic>.from(res['message'] as Map));
        }
        _events = (res['events'] as List<dynamic>? ?? [])
            .map((e) => SmsEventRecord.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyText(String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msg = _record;
    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'Message Details',
              showBackButton: true,
              actions: [
                IconButton(
                  tooltip: 'Refresh Status',
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ],
            ),
            Expanded(
              child: msg == null
                  ? const LoadingState()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        24 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      children: [
                        StatusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      msg.direction,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  StatusBadge(status: msg.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SelectableText(
                                  msg.messageBody,
                                  style: const TextStyle(fontSize: 14.5, height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.copy_rounded, size: 16),
                                      label: const Text('Copy Number', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () => _copyText('Phone number', msg.counterparty),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                                      label: const Text('Copy Text', maxLines: 1, overflow: TextOverflow.ellipsis),
                                      onPressed: () => _copyText('Message', msg.messageBody),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatusCard(
                          child: Column(
                            children: [
                              InfoMetricRow(label: 'Message ID', value: msg.messageUuid, monospace: true, showDivider: true),
                              InfoMetricRow(label: 'Sender Number', value: msg.senderNumber ?? 'Device SIM', showDivider: true),
                              InfoMetricRow(label: 'Recipient Number', value: msg.recipientNumber, showDivider: true),
                              InfoMetricRow(
                                label: 'Sending SIM',
                                value: msg.sendingSimSlot != null
                                    ? 'SIM ${msg.sendingSimSlot! + 1} (Sub ${msg.sendingSubscriptionId ?? '-'})'
                                    : 'N/A',
                                showDivider: true,
                              ),
                              InfoMetricRow(
                                label: 'Receiving SIM',
                                value: msg.receivingSimSlot != null
                                    ? 'SIM ${msg.receivingSimSlot! + 1} (Sub ${msg.receivingSubscriptionId ?? '-'})'
                                    : 'Unknown',
                                showDivider: true,
                              ),
                              InfoMetricRow(label: 'Carrier', value: msg.carrierName ?? 'Unknown', showDivider: true),
                              InfoMetricRow(label: 'Application Source', value: msg.applicationSource, showDivider: true),
                              InfoMetricRow(label: 'Reference ID', value: msg.referenceId ?? '-', showDivider: true),
                              InfoMetricRow(label: 'Encoding / Parts', value: '${msg.encoding} • ${msg.segmentCount} part(s)', showDivider: true),
                              InfoMetricRow(label: 'Priority', value: msg.priority, showDivider: true),
                              InfoMetricRow(label: 'Created At', value: msg.createdAt, showDivider: true),
                              InfoMetricRow(label: 'Queued At', value: msg.queuedAt ?? '-', showDivider: true),
                              InfoMetricRow(label: 'Submitted At', value: msg.submittedAt ?? '-', showDivider: true),
                              InfoMetricRow(
                                label: 'Delivered At',
                                value: msg.deliveredAt ?? (msg.deliveryReportRequested ? 'Pending' : 'Not Requested'),
                                showDivider: true,
                              ),
                              InfoMetricRow(label: 'Retry Count', value: '${msg.retryCount}', showDivider: true),
                              InfoMetricRow(label: 'Failure Reason', value: msg.failureReason ?? 'None', showDivider: true),
                              InfoMetricRow(label: 'Backend Sync', value: msg.syncStatus),
                            ],
                          ),
                        ),
                        if (msg.partStatuses.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const SectionHeader(title: 'Multipart Segment Status'),
                          const SizedBox(height: 6),
                          StatusCard(
                            child: Column(
                              children: msg.partStatuses.asMap().entries.map((entry) {
                                final p = entry.value;
                                return InfoMetricRow(
                                  label: 'Part ${p['part'] ?? '-'}',
                                  value: 'Sent: ${p['sent_status'] ?? '-'} • Delivery: ${p['delivery_status'] ?? '-'}',
                                  showDivider: entry.key < msg.partStatuses.length - 1,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        if (_events.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const SectionHeader(title: 'Event Timeline'),
                          const SizedBox(height: 6),
                          ..._events.map(
                            (ev) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: StatusCard(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ev.eventType,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            ev.eventTimestamp,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(ev.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    if (ev.description != null && ev.description!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(ev.description!, style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
