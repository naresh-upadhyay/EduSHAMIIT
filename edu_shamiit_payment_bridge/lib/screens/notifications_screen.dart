import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_badge.dart';
import '../widgets/dynamic_parser_studio_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedTab = 0; // 0 = Parsed Payments, 1 = Raw Logs
  String _selectedFilter = 'All';
  int _allCount = 0;
  int _matchedCount = 0;
  int _unmatchedCount = 0;
  int _ignoredCount = 0;
  late Future<NotificationsResult> _notificationsFuture;

  // Raw Notifications State
  List<Map<String, dynamic>> _rawNotifications = [];
  bool _isLoadingRaw = false;
  String _rawAppFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchRawNotifications();
  }

  void _fetch() {
    // Proactively sync local device SQLite queue to backend
    PlatformBridge.syncNow().catchError((_) => <String, dynamic>{});
    _fetchRawNotifications();
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

  Future<void> _fetchRawNotifications() async {
    setState(() => _isLoadingRaw = true);
    final raw = await PlatformBridge.getRawNotifications(limit: 100);
    if (mounted) {
      setState(() {
        _rawNotifications = raw;
        _isLoadingRaw = false;
      });
    }
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

  List<Map<String, dynamic>> get _filteredRawNotifications {
    if (_rawAppFilter == 'All') return _rawNotifications;
    return _rawNotifications.where((n) {
      final appName = (n['app_name'] ?? '').toString();
      final pkg = (n['package_name'] ?? '').toString();
      return appName.toLowerCase().contains(_rawAppFilter.toLowerCase()) ||
          pkg.toLowerCase().contains(_rawAppFilter.toLowerCase());
    }).toList();
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
                icon: const Icon(Icons.psychology_alt_rounded, color: Colors.white),
                tooltip: 'Dynamic Parser Studio',
                onPressed: () => DynamicParserStudioDialog.show(
                  context,
                  onSaved: _fetch,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  if (val == 'refresh') {
                    _fetch();
                  } else if (val == 'parser') {
                    DynamicParserStudioDialog.show(context, onSaved: _fetch);
                  } else if (val == 'rebind') {
                    PlatformBridge.forceRebindListener().then((_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Re-bound notification listener to Android OS'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    });
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 18, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text('Refresh All'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'parser',
                    child: Row(
                      children: [
                        Icon(Icons.psychology_alt_rounded, size: 18, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text('Message Parser Studio'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rebind',
                    child: Row(
                      children: [
                        Icon(Icons.sync, size: 18, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text('Force Rebind Listener'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Primary Navigation Switcher: [ Payment Events ] vs [ Raw Notification Logs ]
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? AppColors.primaryNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Payment Events ($_allCount)',
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 1);
                      _fetchRawNotifications();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? AppColors.primaryNavy : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Raw Notification Logs (${_rawNotifications.length})',
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 0 ? _buildParsedPaymentsView() : _buildRawNotificationsView(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PARSED PAYMENT EVENTS VIEW
  // ==========================================
  Widget _buildParsedPaymentsView() {
    return Column(
      children: [
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
                      const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications found for $_selectedFilter',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.elementAt(index);
                    final groupItems = grouped[dateKey]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(dateKey),
                        ...groupItems.map((notif) => _buildNotificationCard(notif)),
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
    );
  }

  // ==========================================
  // TAB 2: RAW NOTIFICATIONS LOGS VIEW
  // ==========================================
  Widget _buildRawNotificationsView() {
    final rawList = _filteredRawNotifications;

    return Column(
      children: [
        // Sub-filter & Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              // Filter chips for apps
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRawFilterChip('All'),
                      const SizedBox(width: 6),
                      _buildRawFilterChip('PhonePe'),
                      const SizedBox(width: 6),
                      _buildRawFilterChip('Google Pay'),
                      const SizedBox(width: 6),
                      _buildRawFilterChip('Paytm'),
                      const SizedBox(width: 6),
                      _buildRawFilterChip('SMS'),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.primaryNavy),
                tooltip: 'Refresh Raw Logs',
                onPressed: _fetchRawNotifications,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.errorRed),
                tooltip: 'Clear Raw Logs',
                onPressed: () async {
                  await PlatformBridge.clearRawNotifications();
                  _fetchRawNotifications();
                },
              ),
            ],
          ),
        ),

        // List of Raw Notifications
        Expanded(
          child: _isLoadingRaw && rawList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : rawList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 54, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No Raw Notifications Captured Yet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryNavy),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Every notification posted by PhonePe, Google Pay, Paytm, or SMS on this device is automatically logged here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => DynamicParserStudioDialog.show(
                                context,
                                onSaved: _fetch,
                              ),
                              icon: const Icon(Icons.psychology_alt_rounded, size: 18),
                              label: const Text('Open Message Parser Studio'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchRawNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: rawList.length,
                        itemBuilder: (context, index) {
                          final item = rawList[index];
                          return _buildRawNotificationCard(item);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildRawFilterChip(String appName) {
    final isSelected = _rawAppFilter == appName;
    return ChoiceChip(
      label: Text(appName, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.primaryNavy)),
      selected: isSelected,
      selectedColor: AppColors.primaryNavy,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      onSelected: (_) => setState(() => _rawAppFilter = appName),
    );
  }

  Widget _buildRawNotificationCard(Map<String, dynamic> raw) {
    final appName = raw['app_name']?.toString() ?? 'App';
    final pkg = raw['package_name']?.toString() ?? '';
    final title = raw['title']?.toString() ?? '(No Title)';
    final content = raw['content']?.toString() ?? '(No Text)';
    final postTime = (raw['post_time'] as num?)?.toInt() ?? 0;
    final status = raw['parsed_status']?.toString() ?? 'UNPARSED';
    final amountPaise = (raw['amount_paise'] as num?)?.toInt() ?? 0;
    final senderName = raw['sender_name']?.toString();
    final bankName = raw['bank_name']?.toString();

    final timeStr = postTime > 0
        ? DateFormat('hh:mm a • dd MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(postTime).toLocal())
        : 'Recently';

    Color appColor = AppColors.primaryNavy;
    if (appName.contains('PhonePe')) appColor = const Color(0xFF5F259F);
    if (appName.contains('Google Pay')) appColor = const Color(0xFF4285F4);
    if (appName.contains('Paytm')) appColor = const Color(0xFF002E6E);
    if (appName.contains('SMS')) appColor = const Color(0xFF0F9D58);

    final isParsed = status == 'PARSED_CREDIT' || amountPaise > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Pill & Time
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: appColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        appName,
                        style: TextStyle(color: appColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pkg,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Notification Title
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),

            // Notification Message Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(fontSize: 12, color: AppColors.primaryNavy),
              ),
            ),
            const SizedBox(height: 10),

            // Parsing status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isParsed ? AppColors.successGreen.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isParsed ? AppColors.successGreen.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isParsed ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                    size: 14,
                    color: isParsed ? AppColors.successGreen : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isParsed
                          ? 'PARSED: ₹${(amountPaise / 100.0).toStringAsFixed(2)} ${senderName != null ? '• $senderName' : ''} ${bankName != null ? '($bankName)' : ''}'
                          : 'STATUS: $status (Amount not detected)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isParsed ? AppColors.successGreen : Colors.orange.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '$title\n$content'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy Text', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => DynamicParserStudioDialog.show(
                    context,
                    initialPackage: pkg,
                    initialTitle: title,
                    initialDescription: content,
                    onSaved: _fetch,
                  ),
                  icon: const Icon(Icons.psychology_alt_rounded, size: 14),
                  label: const Text('Test / Update Parser', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String dateKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primaryBlue),
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
                          notif.eventType == 'PAYMENT_SENT' ? 'Payment Sent' : 'Payment Received',
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                ],
              ),
              const SizedBox(height: 8),

              // Middle: Sender & Reference details
              if (notif.senderName != null || notif.maskedSenderIdentifier != null || notif.transactionReference != null)
                Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 8),
                  child: Text(
                    'From: ${notif.senderName ?? notif.maskedSenderIdentifier ?? "Unknown"} • Ref: ${notif.transactionReference ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Bottom Row: Status Badge & Candidate link
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Row(
                  children: [
                    StatusBadge(
                      status: notif.candidateMatchStatus,
                    ),
                    if (notif.isMatched && notif.matchedStudentName != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Student: ${notif.matchedStudentName} • ${notif.matchedInvoiceNumber ?? ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (notif.isUnmatched) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'No active payment request',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
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
      ),
    );
  }

  void _showNotificationDetailModal(PaymentNotificationItem notif) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notification Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(),
              _buildModalRow('Event ID', notif.eventUuid),
              _buildModalRow('Application', '${notif.sourceApp} (${notif.sourcePackage})'),
              _buildModalRow('Event Type', notif.eventType),
              _buildModalRow('Amount', notif.formattedAmount),
              _buildModalRow('Sender Name', notif.senderName ?? 'Not Available'),
              _buildModalRow('Masked Identifier', notif.maskedSenderIdentifier ?? 'Not Available'),
              _buildModalRow('Reference / UTR', notif.transactionReference ?? 'Not Available'),
              _buildModalRow('Post Time', notif.formattedTime),
              _buildModalRow('Parser Version', notif.parserVersion),
              _buildModalRow('Match Status', notif.candidateMatchStatus),
              const SizedBox(height: 12),
              const Text('Raw Notification Content:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notif.rawText ?? 'Title: ${notif.rawTitle ?? "None"}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    DynamicParserStudioDialog.show(
                      context,
                      initialPackage: notif.sourcePackage,
                      initialTitle: notif.rawTitle,
                      initialDescription: notif.rawText,
                      onSaved: _fetch,
                    );
                  },
                  icon: const Icon(Icons.psychology_alt_rounded, size: 18),
                  label: const Text('Open in Message Parser Studio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
