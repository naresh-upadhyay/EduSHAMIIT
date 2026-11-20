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
import '../widgets/phonepe_filter_dialog.dart';
import '../services/archive_service.dart';
import 'archived_alerts_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const NotificationsScreen({super.key, this.onBack});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  int _selectedTab = 0; // 0 = Parsed Payments, 1 = Raw Logs
  String _selectedFilter = 'All';
  int _allCount = 0;
  int _matchedCount = 0;
  int _unmatchedCount = 0;
  int _ignoredCount = 0;
  late Future<NotificationsResult> _notificationsFuture;

  // Track expanded title groups
  final Set<String> _expandedGroupKeys = {};

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

  void refresh() {
    _fetch();
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
        final activeItems = data.items.where((i) => !ArchiveService().isAlertArchived(i.id)).toList();
        setState(() {
          _allCount = activeItems.length;
          _matchedCount = activeItems.where((i) => i.isMatched).length;
          _unmatchedCount = activeItems.where((i) => i.isUnmatched).length;
          _ignoredCount = activeItems.where((i) => i.isIgnored).length;
        });
      }
    }).catchError((e) {
      debugPrint('[NotificationsScreen] fetch error: $e');
      if (mounted) {
        setState(() {
          _allCount = 0;
          _matchedCount = 0;
          _unmatchedCount = 0;
          _ignoredCount = 0;
        });
      }
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
      // 0. Exclude archived alerts
      if (ArchiveService().isAlertArchived(item.id)) return false;

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
        final title = (n['title'] ?? n['raw_title'] ?? '').toString().toLowerCase();
        final text = (n['text'] ?? n['content'] ?? n['body'] ?? n['raw_text'] ?? '').toString().toLowerCase();
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
                  } else if (val == 'archived') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArchivedAlertsScreen(
                          onAlertsChanged: _fetch,
                        ),
                      ),
                    );
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
                    value: 'archived',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18, color: AppColors.primaryNavy),
                        SizedBox(width: 8),
                        Text('Archived Alerts'),
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
                          _allCount > 0 ? 'Payment Events ($_allCount)' : 'Payment Events',
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
        // Horizontal Pill Filter Bar with Live Counts (Only show when not in an error state with no items)
        FutureBuilder<NotificationsResult>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            final isOffline = snapshot.hasError && (snapshot.data == null || snapshot.data!.items.isEmpty);
            if (isOffline) {
              return const SizedBox.shrink();
            }
            return FilterChipsBar(
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
            );
          },
        ),
        Expanded(
          child: FutureBuilder<NotificationsResult>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _allCount == 0 && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError && (snapshot.data == null || snapshot.data!.items.isEmpty)) {
                return Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 48, color: AppColors.errorRed),
                          const SizedBox(height: 12),
                          const Text(
                            'Could not connect to configured backend target',
                            style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ApiService().baseUrl,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
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
                    ),
                  ),
                );
              }

              if (snapshot.hasData) {
                final data = snapshot.data!;
                final activeItems = data.items.where((i) => !ArchiveService().isAlertArchived(i.id)).toList();
                final calculatedAll = activeItems.length;
                final calculatedMatched = activeItems.where((i) => i.isMatched).length;
                final calculatedUnmatched = activeItems.where((i) => i.isUnmatched).length;
                final calculatedIgnored = activeItems.where((i) => i.isIgnored).length;

                if (_allCount != calculatedAll || _matchedCount != calculatedMatched || _unmatchedCount != calculatedUnmatched) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _allCount = calculatedAll;
                        _matchedCount = calculatedMatched;
                        _unmatchedCount = calculatedUnmatched;
                        _ignoredCount = calculatedIgnored;
                      });
                    }
                  });
                }
              }
              final rawItems = snapshot.data?.items ?? [];
              final filteredItems = _applyAllFilters(rawItems);

              if (filteredItems.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _fetch(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      alignment: Alignment.center,
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
                    ),
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

                    // Sub-group notifications by title under the same card
                    final titleGroups = <String, List<PaymentNotificationItem>>{};
                    for (var notif in groupItems) {
                      final groupTitle = notif.title.trim();
                      titleGroups.putIfAbsent(groupTitle, () => []).add(notif);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateHeader(dateKey),
                        ...titleGroups.entries.map((entry) {
                          final title = entry.key;
                          final items = entry.value;
                          if (items.length > 1) {
                            final groupKey = '$dateKey|$title';
                            return _buildGroupedNotificationCard(groupKey, title, items);
                          } else {
                            return _buildNotificationCard(items.first);
                          }
                        }),
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
    final title = (n['title'] ?? n['raw_title'] ?? '').toString().trim();
    final text = (n['text'] ?? n['content'] ?? n['body'] ?? n['raw_text'] ?? n['description'] ?? '').toString().trim();
    final pkg = (n['package_name'] ?? '').toString().trim();
    final appName = (n['app_name'] ?? '').toString().trim();
    final timeMs = n['post_time'] as int? ?? 0;
    final timeStr = timeMs > 0
        ? DateFormat('dd MMM, hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timeMs))
        : 'Unknown time';

    void openParserStudio() {
      DynamicParserStudioDialog.show(
        context,
        initialPackage: pkg.isNotEmpty ? pkg : 'com.phonepe.app',
        initialTitle: title.isNotEmpty ? title : 'Notification',
        initialDescription: text.isNotEmpty ? text : (title.isNotEmpty ? title : 'Payment notification received'),
        onSaved: _fetch,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: openParserStudio,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      appName.isNotEmpty ? appName : (pkg.isNotEmpty ? pkg.split('.').last : 'App'),
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
              ] else ...[
                const SizedBox(height: 4),
                const Text(
                  '(No notification body text)',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: openParserStudio,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 13, color: AppColors.primaryBlue),
                          SizedBox(width: 4),
                          Text(
                            'Test in Parser Studio',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ],
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

  Widget _buildGroupedNotificationCard(
    String groupKey,
    String title,
    List<PaymentNotificationItem> items,
  ) {
    final isExpanded = _expandedGroupKeys.contains(groupKey);
    final totalPaise = items.fold<int>(0, (sum, i) => sum + i.amountPaise);
    final totalFormatted = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(totalPaise / 100.0);

    final firstItem = items.first;
    final sourceApp = firstItem.sourceApp;
    final hasMatched = items.any((i) => i.isMatched);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded ? AppColors.primaryNavy.withValues(alpha: 0.4) : AppColors.border,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isExpanded ? 0.04 : 0.02),
            blurRadius: isExpanded ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Group Header Card (clickable to expand/collapse)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedGroupKeys.remove(groupKey);
                } else {
                  _expandedGroupKeys.add(groupKey);
                }
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(isExpanded ? 0 : 14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // App / Group Icon with Badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasMatched ? AppColors.successGreenBg : AppColors.primaryNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: hasMatched ? AppColors.successGreen : AppColors.primaryNavy,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Title and App Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              sourceApp,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${items.length} alerts grouped',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Amount Sum and Expand Chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalFormatted,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isExpanded ? 'Hide' : 'View all',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isExpanded ? AppColors.primaryBlue : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: isExpanded ? AppColors.primaryBlue : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Items List
          if (isExpanded) ...[
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Column(
                children: [
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final notif = entry.value;
                    final isLast = idx == items.length - 1;
                    final subItemWidget = InkWell(
                      onTap: () => _showNotificationDetailModal(context, notif),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: notif.isMatched ? AppColors.successGreen : AppColors.warningOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        notif.formattedTime,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      if (notif.maskedSender != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• From ${notif.maskedSender}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (notif.reference != null && notif.reference!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ref: ${notif.reference}',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  StatusBadge(status: notif.matchStatus),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  notif.formattedAmount,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Details',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primaryBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.chevron_right, size: 14, color: AppColors.primaryBlue),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );

                    return Dismissible(
                      key: Key('sub_notif_${notif.id}'),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        if (!notif.canArchive) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Matched payments are immutable financial records and cannot be archived.',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.errorRed,
                              duration: Duration(seconds: 5),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (direction) async {
                        await ArchiveService().archiveAlert(notif.id);
                        _fetch();
                        if (mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Archived "${notif.title}" (${notif.formattedAmount})'),
                              backgroundColor: AppColors.primaryNavy,
                              duration: const Duration(seconds: 5),
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: AppColors.primaryBlueLight,
                                onPressed: () async {
                                  await ArchiveService().unarchiveAlert(notif.id);
                                  _fetch();
                                },
                              ),
                            ),
                          );
                          Future.delayed(const Duration(milliseconds: 5200), () {
                            if (mounted) {
                              messenger.hideCurrentSnackBar();
                            }
                          });
                        }
                      },
                      background: _buildArchiveSwipeBackground(Alignment.centerLeft, isSubItem: true),
                      secondaryBackground: _buildArchiveSwipeBackground(Alignment.centerRight, isSubItem: true),
                      child: subItemWidget,
                    );
                  }),
                ],
              ),
            ),
          ],
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

    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showNotificationDetailModal(context, notif),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusFgColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                    StatusBadge(status: notif.matchStatus),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    notif.formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: AppColors.primaryBlue),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (!notif.canArchive) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Matched & verified payments are immutable financial records and cannot be archived.',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorRed,
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(milliseconds: 5200), () {
            if (mounted) messenger.hideCurrentSnackBar();
          });
          return false;
        }
        return true;
      },
      onDismissed: (direction) async {
        await ArchiveService().archiveAlert(notif.id);
        _fetch();
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Archived "${notif.title}" (${notif.formattedAmount})'),
              backgroundColor: AppColors.primaryNavy,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.primaryBlueLight,
                onPressed: () async {
                  await ArchiveService().unarchiveAlert(notif.id);
                  _fetch();
                },
              ),
            ),
          );
          Future.delayed(const Duration(milliseconds: 5200), () {
            if (mounted) {
              messenger.hideCurrentSnackBar();
            }
          });
        }
      },
      background: _buildArchiveSwipeBackground(Alignment.centerLeft),
      secondaryBackground: _buildArchiveSwipeBackground(Alignment.centerRight),
      child: cardWidget,
    );
  }

  Widget _buildArchiveSwipeBackground(Alignment alignment, {bool isSubItem = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isSubItem ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(isSubItem ? 0 : 12),
      ),
      alignment: alignment,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text(
            'Archive',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetailModal(BuildContext context, PaymentNotificationItem notif) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Drag Handle Pill
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notif.sourceApp,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: notif.matchStatus),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),

                  // Scrollable Content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(18),
                      children: [
                        // Amount Banner Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryNavy, Color(0xFF1E3A8A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TRANSACTION AMOUNT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    notif.formattedAmount,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Credited to UPI',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Received: ${DateFormat('dd MMMM yyyy, hh:mm:ss a').format(notif.notificationTimestamp.toLocal())}',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 1: ACTUAL RAW NOTIFICATION RECEIVED
                        const Text(
                          'ACTUAL NOTIFICATION RECEIVED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Raw Title
                              Row(
                                children: [
                                  const Icon(Icons.title_rounded, size: 16, color: AppColors.primaryNavy),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Notification Title:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: notif.rawTitle ?? notif.title));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Title copied to clipboard'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryBlue),
                                        SizedBox(width: 2),
                                        Text(
                                          'Copy',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                notif.rawTitle ?? notif.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Divider(height: 18, color: AppColors.border),

                              // Raw Body / Description
                              Row(
                                children: [
                                  const Icon(Icons.description_outlined, size: 16, color: AppColors.primaryNavy),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Message Body / Description:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: notif.rawText ?? notif.title));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Description copied to clipboard'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryBlue),
                                        SizedBox(width: 2),
                                        Text(
                                          'Copy',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primaryBlue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: SelectableText(
                                  (notif.rawText != null && notif.rawText!.isNotEmpty)
                                      ? notif.rawText!
                                      : '(No body text captured for this notification)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 2: EXTRACTED FINANCIAL METADATA
                        const Text(
                          'EXTRACTED TRANSACTION METADATA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              _buildMetaRow('Sender / Payer', notif.senderName ?? notif.maskedSender ?? 'Unknown'),
                              _buildMetaRow('NPCI UTR / Ref', notif.reference ?? 'Not found', isCopyable: true),
                              _buildMetaRow('Android Package', notif.sourcePackage.isNotEmpty ? notif.sourcePackage : 'N/A'),
                              _buildMetaRow('Parser Engine', 'v${notif.parserVersion} • ${notif.confidenceScore} Confidence'),
                              if (notif.isMatched) ...[
                                _buildMetaRow('Matched Student', notif.matchedStudentName ?? 'Verified', highlight: true),
                                if (notif.matchedInvoiceNumber != null)
                                  _buildMetaRow('Invoice No.', notif.matchedInvoiceNumber!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 3: PARSER STUDIO TESTING & CUSTOMIZATION CTA
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.psychology_alt_rounded, color: Color(0xFF166534), size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Parser Studio Testing & Customization',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Need to fine-tune pattern extraction, update regex rules, or calibrate parsing for this specific alert format? Open directly in Parser Studio.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF15803D), height: 1.4),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    DynamicParserStudioDialog.show(
                                      context,
                                      initialPackage: notif.sourcePackage.isNotEmpty ? notif.sourcePackage : 'com.phonepe.app',
                                      initialTitle: notif.rawTitle ?? notif.title,
                                      initialDescription: notif.rawText ?? notif.title,
                                      onSaved: _fetch,
                                    );
                                  },
                                  icon: const Icon(Icons.tune_rounded, size: 18),
                                  label: const Text(
                                    'Open in Parser Studio & Test',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryNavy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isCopyable = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? AppColors.successGreen : AppColors.textPrimary,
              ),
            ),
          ),
          if (isCopyable && value != 'Not found') ...[
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }
}
