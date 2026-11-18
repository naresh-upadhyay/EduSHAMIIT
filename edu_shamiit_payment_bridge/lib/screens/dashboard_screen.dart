import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/platform_bridge.dart';
import '../models/dashboard_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_header.dart';
import '../widgets/metric_card.dart';
import 'diagnostics_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  late Future<DashboardData> _dashboardFuture;
  DashboardData? _cachedData;
  StreamSubscription? _wsSubscription;
  DateTime _lastRefreshTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isFetching = false;
  bool _isListenerActive = false;
  bool _notificationAccessGranted = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _checkNativeStatus();
    
    // Smart WebSocket subscription - only react to real payment business events
    _wsSubscription = WebSocketService().stream.listen((event) {
      final type = (event['type'] ?? event['event'] ?? '').toString().toUpperCase();
      // Completely ignore heartbeat pings/pongs to avoid burdening the backend
      if (type == 'PONG' || type == 'PING' || type == 'DEVICE_HEARTBEAT') {
        return;
      }
      
      // Real-time direct payload update if provided
      if (type == 'DASHBOARD_UPDATE' && event['data'] != null) {
        try {
          final updated = DashboardData.fromJson(Map<String, dynamic>.from(event['data']));
          if (mounted) {
            setState(() {
              _cachedData = updated;
            });
          }
          return;
        } catch (_) {}
      }

      // Business event received - throttle and refresh
      if (type == 'PAYMENT_RECEIVED' || type == 'PAYMENT_CONFIRMED' || 
          type == 'PAYMENT_VERIFIED' || type == 'NOTIFICATION_INGESTED' ||
          type == 'FORCE_SYNC' || type == 'METRICS_UPDATED') {
        _throttledRefresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativeStatus();
      // Only refresh on resume if at least 60 seconds elapsed to prevent burdening API
      final now = DateTime.now();
      if (now.difference(_lastRefreshTime).inSeconds >= 60) {
        _throttledRefresh();
      }
    }
  }

  Future<void> _checkNativeStatus() async {
    final granted = await PlatformBridge.hasNotificationAccess();
    final running = await PlatformBridge.isListenerRunning();
    if (mounted) {
      setState(() {
        _notificationAccessGranted = granted;
        _isListenerActive = granted && running;
      });
    }
  }

  void _throttledRefresh() {
    final now = DateTime.now();
    if (now.difference(_lastRefreshTime).inSeconds < 5 || _isFetching) {
      return; // Rate limit to at most once every 5 seconds
    }
    _refresh();
  }

  void _refresh() {
    _isFetching = true;
    _lastRefreshTime = DateTime.now();
    // Proactively sync local device SQLite queue to backend
    PlatformBridge.syncNow().catchError((_) => <String, dynamic>{});
    final future = ApiService().getDashboardData();
    setState(() {
      _dashboardFuture = future;
    });
    future.then((data) {
      if (mounted) {
        setState(() {
          _cachedData = data;
          _isFetching = false;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    });
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronizing payment events with backend...'),
        duration: Duration(seconds: 1),
      ),
    );
    await PlatformBridge.syncNow();
    await ApiService().syncNow();
    await Future.delayed(const Duration(milliseconds: 600));
    _refresh();
    await _checkNativeStatus();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronization complete! All queues up to date.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Payment Bridge',
            showRunningBadge: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'diagnostics') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DiagnosticsScreen(),
                      ),
                    );
                  } else if (value == 'refresh') {
                    _refresh();
                    _checkNativeStatus();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'diagnostics',
                    child: Row(
                      children: [
                        Icon(Icons.monitor_heart, color: AppColors.primaryBlue, size: 20),
                        SizedBox(width: 10),
                        Text('Device Diagnostics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: AppColors.textPrimary, size: 20),
                        SizedBox(width: 10),
                        Text('Refresh Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _checkNativeStatus();
              },
              child: FutureBuilder<DashboardData>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  // Only show full screen spinner on very first load before any data is cached
                  if (snapshot.connectionState == ConnectionState.waiting && _cachedData == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final hasError = snapshot.hasError && _cachedData == null;
                  final data = snapshot.data ?? _cachedData ?? DashboardData.empty(isConnected: false);
                  final bottomSafePadding = MediaQuery.of(context).padding.bottom;

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      bottomSafePadding > 0 ? bottomSafePadding + 32 : 36,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasError)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cloud_off, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Server Disconnected: ${snapshot.error}',
                                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _refresh,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        // Card 1: Payment Listener Switch
                        _buildListenerActiveCard(data),
                        const SizedBox(height: 12),

                        // Card 2: 4 Metric Cards
                        _buildMetricCardsRow(data.metrics),
                        const SizedBox(height: 12),

                        // Card 3: System Status Checklist
                        _buildSystemStatusCard(data.systemStatus),
                        const SizedBox(height: 12),

                        // Card 4: Today's Activity Feed
                        _buildTodayActivityCard(data.todayActivity),
                        const SizedBox(height: 16),

                        // Card 5: Sync Now Button
                        ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _handleSyncNow,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 20),
                          label: Text(
                            _isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Last successful sync: ${data.metrics.lastSyncTime}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenerActiveCard(DashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isListenerActive ? const Color(0xFFE8F8EE) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isListenerActive ? const Color(0xFFB7E4C7) : const Color(0xFFFCA5A5),
                ),
              ),
              child: Icon(
                Icons.phone_android,
                color: _isListenerActive ? const Color(0xFF10A352) : const Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isListenerActive ? 'Payment Listener Active' : 'Payment Listener Inactive',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isListenerActive
                        ? 'Monitoring UPI payment notifications'
                        : 'Grant notification permission to monitor UPI',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isListenerActive,
              activeThumbColor: const Color(0xFF10A352),
              onChanged: (val) async {
                if (!_notificationAccessGranted) {
                  await PlatformBridge.openNotificationSettings();
                } else {
                  if (val) {
                    await PlatformBridge.startListenerService();
                  } else {
                    await PlatformBridge.stopListenerService();
                  }
                  setState(() => _isListenerActive = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCardsRow(DashboardMetrics m) {
    return Row(
      children: [
        Expanded(
          child: DashboardMetricCard(
            label: 'Notifications\nToday',
            value: '${m.notificationsToday}',
            icon: Icons.notifications_none,
            iconColor: const Color(0xFF8E44AD),
            iconBgColor: const Color(0xFFF4ECF7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DashboardMetricCard(
            label: 'Matched\nPayments',
            value: '${m.matchedPayments}',
            icon: Icons.currency_rupee,
            iconColor: const Color(0xFF10A352),
            iconBgColor: const Color(0xFFE8F8EE),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DashboardMetricCard(
            label: 'Unmatched\nPayments',
            value: '${m.unmatchedPayments}',
            icon: Icons.priority_high,
            iconColor: const Color(0xFFE67E22),
            iconBgColor: const Color(0xFFFFF4E5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DashboardMetricCard(
            label: 'Last Sync',
            value: m.lastSyncTime,
            subtitle: '(Just now)',
            icon: Icons.history,
            iconColor: const Color(0xFF0B63F6),
            iconBgColor: const Color(0xFFE8F1FE),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusCard(SystemStatus s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.show_chart, color: AppColors.primaryBlue, size: 20),
                SizedBox(width: 8),
                Text(
                  'System Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildStatusRow(
              icon: Icons.notifications_active_outlined,
              title: 'Notification Access',
              badgeText: _notificationAccessGranted ? 'Granted' : 'Permission Required',
              isWarning: !_notificationAccessGranted,
              onTap: () => PlatformBridge.openNotificationSettings(),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.grid_view_rounded,
              title: 'Monitored UPI Apps',
              badgeText: s.monitoredUpiApps,
              onTap: () => widget.onNavigateTab(3),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.language,
              title: 'Backend Connection',
              badgeText: s.backendConnection,
              onTap: () => widget.onNavigateTab(3),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.phonelink_setup,
              title: 'Device Registration',
              badgeText: s.deviceRegistration,
              onTap: () => widget.onNavigateTab(3),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.sync,
              title: 'Data Sync',
              badgeText: s.dataSync,
              onTap: () => _handleSyncNow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String title,
    required String badgeText,
    bool isWarning = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isWarning ? AppColors.warningOrange : AppColors.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWarning ? Icons.warning_amber_rounded : Icons.check,
                  size: 14,
                  color: isWarning ? AppColors.warningOrange : AppColors.successGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWarning ? AppColors.warningOrange : AppColors.successGreen,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayActivityCard(List<ActivityItem> activities) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, color: AppColors.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Today's Activity",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => widget.onNavigateTab(1),
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primaryBlue),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No activities detected today yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              ...activities.map((item) => _buildActivityRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(ActivityItem item) {
    Color iconBg;
    Color iconFg;
    IconData icon;

    switch (item.iconType) {
      case 'SUCCESS':
        icon = Icons.check;
        iconBg = const Color(0xFFE8F8EE);
        iconFg = const Color(0xFF10A352);
        break;
      case 'WARNING':
        icon = Icons.priority_high;
        iconBg = const Color(0xFFFFF4E5);
        iconFg = const Color(0xFFE67E22);
        break;
      case 'IGNORED':
        icon = Icons.arrow_outward;
        iconBg = const Color(0xFFF1F5F9);
        iconFg = const Color(0xFF64748B);
        break;
      default:
        icon = Icons.notifications_none;
        iconBg = const Color(0xFFE8F1FE);
        iconFg = const Color(0xFF0B63F6);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.time,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
