import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_badge.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';
  int _allCount = 0;
  int _matchedCount = 0;
  int _unmatchedCount = 0;
  int _ignoredCount = 0;
  late Future<NotificationsResult> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final future = ApiService().getNotificationsWithSummary(status: _selectedFilter);
    setState(() {
      _notificationsFuture = future;
    });
    future.then((data) {
      if (mounted) {
        setState(() {
          _allCount = data.allCount;
          _matchedCount = data.matchedCount;
          _unmatchedCount = data.unmatchedCount;
          _ignoredCount = data.ignoredCount;
        });
      }
    }).catchError((e) {
      debugPrint('[NotificationsScreen] fetch error: $e');
    });
  }

  int _getCountFor(String filter) {
    switch (filter) {
      case 'Matched':
        return _matchedCount;
      case 'Unmatched':
        return _unmatchedCount;
      case 'Ignored':
        return _ignoredCount;
      case 'All':
      default:
        return _allCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Notifications',
            showBackButton: true,
            onBackPressed: widget.onBack,
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () => _showFilterDialog(),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  if (val == 'refresh') _fetch();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Text('Refresh Notifications'),
                  ),
                ],
              ),
            ],
          ),
          // Horizontal Pill Filter Bar with Live Counts
          FilterChipsBar(
            options: [
              'All ($_allCount)',
              'Matched ($_matchedCount)',
              'Unmatched ($_unmatchedCount)',
              'Ignored ($_ignoredCount)',
            ],
            selected: '$_selectedFilter (${_getCountFor(_selectedFilter)})',
            onSelected: (val) {
              final clean = val.split(' ').first;
              setState(() => _selectedFilter = clean);
              _fetch();
            },
          ),
          Expanded(
            child: FutureBuilder<NotificationsResult>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _allCount == 0) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError && (snapshot.data == null || snapshot.data!.items.isEmpty)) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: AppColors.errorRed),
                        const SizedBox(height: 12),
                        const Text('Offline: Could not connect to server', style: TextStyle(color: AppColors.errorRed)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _fetch,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  if (_allCount != data.allCount || _matchedCount != data.matchedCount) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _allCount = data.allCount;
                          _matchedCount = data.matchedCount;
                          _unmatchedCount = data.unmatchedCount;
                          _ignoredCount = data.ignoredCount;
                        });
                      }
                    });
                  }
                }
                final items = snapshot.data?.items ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_off_outlined,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications found for $_selectedFilter',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Group by Date Group Key
                final grouped = <String, List<PaymentNotificationItem>>{};
                for (var item in items) {
                  grouped.putIfAbsent(item.dateGroupKey, () => []).add(item);
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetch(),
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, index) {
                      final dateKey = grouped.keys.elementAt(index);
                      final groupItems = grouped[dateKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateHeader(dateKey),
                          ...groupItems
                              .map((notif) => _buildNotificationCard(notif)),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String dateKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            dateKey,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(PaymentNotificationItem notif) {
    Color iconBg;
    Color iconFg;
    IconData icon;

    if (notif.eventType == 'PAYMENT_SENT') {
      icon = Icons.arrow_outward;
      iconBg = AppColors.ignoredGreyBg;
      iconFg = AppColors.ignoredGrey;
    } else if (notif.candidateMatchStatus == 'MATCHED_CANDIDATE') {
      icon = Icons.check;
      iconBg = AppColors.successGreenBg;
      iconFg = AppColors.successGreen;
    } else if (notif.candidateMatchStatus == 'UNMATCHED') {
      icon = Icons.priority_high;
      iconBg = AppColors.warningOrangeBg;
      iconFg = AppColors.warningOrange;
    } else {
      icon = Icons.sync_problem;
      iconBg = AppColors.ignoredGreyBg;
      iconFg = AppColors.ignoredGrey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showNotificationDetailModal(notif),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Title & Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconFg, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif.eventType == 'PAYMENT_SENT'
                              ? 'Payment Sent'
                              : 'Payment Received',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${notif.sourceApp} • ${notif.formattedTime}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    notif.formattedAmount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 8),

              // Middle: From / Ref
              Text(
                'From: ${notif.maskedSenderIdentifier ?? '**** 0000'}${notif.transactionReference != null ? ' • Ref: ${notif.transactionReference}' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Bottom row: Badges
              Row(
                children: [
                  StatusBadge(status: notif.candidateMatchStatus),
                  const SizedBox(width: 8),
                  if (notif.matchedStudentName != null &&
                      notif.matchedInvoiceNumber != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Student: ${notif.matchedStudentName} • ${notif.matchedInvoiceNumber}',
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else if (notif.candidateMatchStatus == 'UNMATCHED')
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'No active payment request',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else if (notif.eventType == 'PAYMENT_SENT')
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Not a receipt',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Notifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...['All', 'Matched', 'Unmatched', 'Ignored'].map((f) {
                return ListTile(
                  title: Text(f),
                  trailing: _selectedFilter == f
                      ? const Icon(Icons.check, color: AppColors.primaryBlue)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedFilter = f);
                    _fetch();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationDetailModal(PaymentNotificationItem notif) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalRow('Source App', notif.sourceApp),
                      _buildModalRow('Package Name', notif.sourcePackage),
                      _buildModalRow('Amount (Paise)',
                          '${notif.amountPaise} paise (${notif.formattedAmount})'),
                      _buildModalRow('Reference / UTR',
                          notif.transactionReference ?? 'Not extracted'),
                      _buildModalRow('Masked Sender',
                          notif.maskedSenderIdentifier ?? 'Unknown'),
                      _buildModalRow('Event UUID', notif.eventUuid),
                      _buildModalRow('Parser Version', notif.parserVersion),
                      _buildModalRow('Confidence Score', notif.confidenceScore),
                      _buildModalRow(
                          'Match Status', notif.candidateMatchStatus),
                      if (notif.matchedStudentName != null)
                        _buildModalRow(
                            'Associated Student', notif.matchedStudentName!),
                      if (notif.matchedInvoiceNumber != null)
                        _buildModalRow(
                            'Associated Invoice', notif.matchedInvoiceNumber!),
                      const SizedBox(height: 12),
                      const Text(
                        'Raw Notification Payload',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notif.rawText ?? 'Title: ${notif.rawTitle ?? "None"}',
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
