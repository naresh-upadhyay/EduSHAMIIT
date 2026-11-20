import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_badge.dart';
import '../widgets/dynamic_parser_studio_dialog.dart';
import '../widgets/phonepe_filter_dialog.dart';

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

  // PhonePe Search & Multi-Criteria Filter State
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  PhonePeFilterState _filterState = const PhonePeFilterState();

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _openPhonePeFilters() async {
    final result = await showDialog<PhonePeFilterState>(
      context: context,
      builder: (_) => PhonePeFilterDialog(
        initialState: _filterState,
        isForAlerts: true,
      ),
    );
    if (result != null) {
      setState(() {
        _filterState = result;
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

  List<PaymentNotificationItem> _applyAllFilters(List<PaymentNotificationItem> raw) {
    return raw.where((item) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesQuery = item.sourceApp.toLowerCase().contains(q) ||
            item.title.toLowerCase().contains(q) ||
            item.formattedAmount.toLowerCase().contains(q) ||
            (item.senderName?.toLowerCase().contains(q) ?? false) ||
            (item.maskedSenderIdentifier?.toLowerCase().contains(q) ?? false) ||
            (item.transactionReference?.toLowerCase().contains(q) ?? false) ||
            (item.rawText?.toLowerCase().contains(q) ?? false);
        if (!matchesQuery) return false;
      }

      // 2. Month filter
      if (_filterState.selectedMonths.isNotEmpty) {
        final dt = item.parsedDateTime;
        final monthStr = DateFormat('MMM yyyy').format(dt).toLowerCase();
        final matchesMonth = _filterState.selectedMonths.any((m) =>
            m.toLowerCase().contains(monthStr) || monthStr.contains(m.toLowerCase().split(' ').first));
        if (!matchesMonth) return false;
      }

      // 3. Instrument / App filter
      if (_filterState.selectedInstruments.isNotEmpty) {
        final matchesApp = _filterState.selectedInstruments.any((inst) {
          final instLower = inst.toLowerCase();
          final appLower = item.sourceApp.toLowerCase();
          return appLower.contains(instLower) || instLower.contains(appLower);
        });
        if (!matchesApp) return false;
      }

      // 4. Status filter
      if (_filterState.selectedStatuses.isNotEmpty) {
        bool matchesStatus = false;
        for (final st in _filterState.selectedStatuses) {
          final sLower = st.toLowerCase();
          if (sLower.contains('matched') && item.isMatched) matchesStatus = true;
          if (sLower.contains('unmatched') && item.isUnmatched) matchesStatus = true;
          if (sLower.contains('review') && item.isReviewRequired) matchesStatus = true;
          if (sLower.contains('ignored') && item.isIgnored) matchesStatus = true;
          if (sLower.contains('duplicate') && item.isDuplicate) matchesStatus = true;
        }
        if (!matchesStatus) return false;
      }

      // 5. Payment Types (Credit / Debit)
      if (_filterState.selectedPaymentTypes.isNotEmpty) {
        final isCredit = item.eventType == 'PAYMENT_RECEIVED';
        final wantsCredit = _filterState.selectedPaymentTypes.any((t) => t.toLowerCase().contains('credit') || t.toLowerCase().contains('received'));
        final wantsDebit = _filterState.selectedPaymentTypes.any((t) => t.toLowerCase().contains('debit') || t.toLowerCase().contains('sent'));
        if (isCredit && !wantsCredit && wantsDebit) return false;
        if (!isCredit && !wantsDebit && wantsCredit) return false;
      }

      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRawNotifications {
    var list = _rawNotifications;
    if (_rawAppFilter != 'All') {
      list = list.where((n) {
        final appName = (n['app_name'] ?? '').toString();
        final pkg = (n['package_name'] ?? '').toString();
        return appName.toLowerCase().contains(_rawAppFilter.toLowerCase()) ||
            pkg.toLowerCase().contains(_rawAppFilter.toLowerCase());
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final text = (n['text'] ?? '').toString().toLowerCase();
        final pkg = (n['package_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || text.contains(q) || pkg.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Alerts',
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
                    final messenger = ScaffoldMessenger.of(context);
                    PlatformBridge.forceRebindListener().then((_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Re-bound notification listener to Android OS'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                          'Raw Logs (${_rawNotifications.length})',
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

          // PhonePe-Style Search & Filters Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search payer, UTR, amount, or text...',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                Container(
                  height: 20,
                  width: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryNavy),
                      if (!_filterState.isEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5F259F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Filters',
                  onPressed: _openPhonePeFilters,
                ),
              ],
            ),
          ),

          // Active Filters Pills Bar
          if (!_filterState.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._filterState.selectedMonths.map((m) => _buildActiveFilterChip(m, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedMonths: Set.from(_filterState.selectedMonths)..remove(m),
                            );
                          });
                        })),
                    ..._filterState.selectedInstruments.map((inst) => _buildActiveFilterChip(inst, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedInstruments: Set.from(_filterState.selectedInstruments)..remove(inst),
                            );
                          });
                        })),
                    ..._filterState.selectedStatuses.map((st) => _buildActiveFilterChip(st, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedStatuses: Set.from(_filterState.selectedStatuses)..remove(st),
                            );
                          });
                        })),
                    InkWell(
                      onTap: () {
                        setState(() => _filterState = const PhonePeFilterState());
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Clear all',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF5F259F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5F259F))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF5F259F)),
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
              final rawItems = snapshot.data?.items ?? [];
              final filteredItems = _applyAllFilters(rawItems);

              if (filteredItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty || !_filterState.isEmpty
                            ? 'No alerts match your filter criteria'
                            : 'No alerts found for $_selectedFilter',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              // Group by Date Group Key
              final grouped = <String, List<PaymentNotificationItem>>{};
              for (var item in filteredItems) {
                grouped.putIfAbsent(item.dateGroupKey, () => []).add(item);
              }

              final bottomSafePadding = MediaQuery.of(context).padding.bottom;
              return RefreshIndicator(
                onRefresh: () async => _fetch(),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    bottomSafePadding > 0 ? bottomSafePadding + 32 : 36,
                  ),
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
                      _buildRawFilterChip('Canara'),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            _rawAppFilter == 'All'
                                ? 'No raw notifications received yet.\nThey will appear here as soon as apps post them.'
                                : 'No notifications found for $_rawAppFilter',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: rawList.length,
                      itemBuilder: (context, index) {
                        final n = rawList[index];
                        return _buildRawNotificationCard(n);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRawFilterChip(String appName) {
    final isSelected = _rawAppFilter == appName;
    return InkWell(
      onTap: () => setState(() => _rawAppFilter = appName),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
          ),
        ),
        child: Text(
          appName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRawNotificationCard(Map<String, dynamic> n) {
    final title = (n['title'] ?? '').toString();
    final text = (n['text'] ?? '').toString();
    final pkg = (n['package_name'] ?? '').toString();
    final appName = (n['app_name'] ?? '').toString();
    final timeMs = n['post_time'] as int? ?? 0;
    final timeStr = timeMs > 0
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timeMs))
        : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  appName.isNotEmpty ? appName : pkg.split('.').last,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHeader(String dateKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primaryNavy),
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
    Color statusBgColor;
    Color statusFgColor;
    IconData statusIcon;

    if (notif.isMatched) {
      statusBgColor = AppColors.successGreenBg;
      statusFgColor = AppColors.successGreen;
      statusIcon = Icons.check_circle_outline;
    } else if (notif.isUnmatched) {
      statusBgColor = AppColors.warningOrangeBg;
      statusFgColor = AppColors.warningOrange;
      statusIcon = Icons.warning_amber_rounded;
    } else if (notif.isReviewRequired) {
      statusBgColor = AppColors.pendingBlueBg;
      statusFgColor = AppColors.pendingBlue;
      statusIcon = Icons.help_outline_rounded;
    } else {
      statusBgColor = AppColors.backgroundLight;
      statusFgColor = AppColors.textMuted;
      statusIcon = Icons.block_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: statusBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusFgColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notif.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              notif.formattedAmount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              '${notif.sourceApp} • ${notif.formattedTime}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (notif.maskedSender != null || notif.reference != null) ...[
              const SizedBox(height: 3),
              Text(
                'From: ${notif.maskedSender ?? 'Unknown'} • Ref: ${notif.reference ?? 'N/A'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            StatusBadge(
              status: notif.matchStatus,
            ),
          ],
        ),
      ),
    );
  }
}
