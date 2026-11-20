import 'dart:async';
import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/dashboard_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_drawer.dart';
import 'diagnostics_screen.dart';

class InsightsScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const InsightsScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<InsightsScreen> createState() => InsightsScreenState();
}

class InsightsScreenState extends State<InsightsScreen> {
  late Future<DashboardData> _dashboardFuture;
  bool _isListenerActive = true;
  bool _notificationAccessGranted = true;
  bool _isSyncing = false;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkListenerStatus();

    _wsSub = WebSocketService().notificationStream.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _loadData() {
    _dashboardFuture = ApiService().getDashboardData();
  }

  Future<void> _checkListenerStatus() async {
    final granted = await PlatformBridge.isNotificationAccessGranted();
    final isRunning = await PlatformBridge.isListenerServiceRunning();
    if (mounted) {
      setState(() {
        _notificationAccessGranted = granted;
        _isListenerActive = isRunning && granted;
      });
    }
  }

  Future<void> refresh() async {
    _checkListenerStatus();
    setState(() {
      _loadData();
    });
  }

  Future<void> _refresh() => refresh();

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await ApiService().triggerSync();
      await _refresh();
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'Sync completed successfully!' : 'Sync completed.'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(milliseconds: 5200), () {
        if (mounted) scaffoldMessenger.hideCurrentSnackBar();
      });
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(milliseconds: 5200), () {
        if (mounted) scaffoldMessenger.hideCurrentSnackBar();
      });
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          AppHeader(
            title: 'System Insights',
            showRunningBadge: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Insights',
                onPressed: _refresh,
              ),
              IconButton(
                icon: const Icon(Icons.phonelink_setup_rounded, color: Colors.white),
                tooltip: 'Full Diagnostics',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primaryBlue,
              child: FutureBuilder<DashboardData>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  final isOffline = snapshot.hasError;
                  final data = snapshot.hasData
                      ? snapshot.data!
                      : DashboardData.empty(status: isOffline ? 'Offline' : 'Connecting...', isConnected: false);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      if (isOffline)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.errorRedBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_off, color: AppColors.errorRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Backend server unreachable',
                                      style: TextStyle(fontSize: 12, color: AppColors.errorRed, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ApiService().baseUrl,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorRed)),
                              ),
                            ],
                          ),
                        ),
                      // Card 1: Listener Active Toggle
                      _buildListenerActiveCard(),
                      const SizedBox(height: 12),

                      // Card 2: System Status Checklist
                      _buildSystemStatusCard(data.systemStatus),
                      const SizedBox(height: 12),

                      // Card 3: Today's Activity Live Feed
                      _buildTodayActivityCard(data.todayActivity),
                      const SizedBox(height: 16),

                      // Card 4: Quick Action Sync
                      ElevatedButton.icon(
                        onPressed: _isSyncing ? null : _handleSyncNow,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Last successful sync: ${data.metrics.lastSyncTime}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenerActiveCard() {
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
                  await PlatformBridge.setListenerActive(val);
                  setState(() => _isListenerActive = val);
                }
              },
            ),
          ],
        ),
      ),
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
              onTap: () => widget.onNavigateTab(2), // Navigate to Alerts
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.language,
              title: 'Backend Connection',
              badgeText: s.backendConnection,
              onTap: () => _refresh(),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.phonelink_setup,
              title: 'Device Registration',
              badgeText: s.deviceRegistration,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                );
              },
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
                TextButton(
                  onPressed: () => widget.onNavigateTab(2), // Navigate to Alerts
                  child: const Text('View All >', style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activities.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No activity recorded today', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              )
            else
              ...activities.take(6).map((activity) => _buildActivityRow(activity)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(ActivityItem item) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    switch (item.iconType) {
      case 'SUCCESS':
        iconColor = AppColors.successGreen;
        iconBg = const Color(0xFFE8F8EE);
        iconData = Icons.check;
        break;
      case 'WARNING':
        iconColor = AppColors.warningOrange;
        iconBg = const Color(0xFFFFF4E5);
        iconData = Icons.priority_high;
        break;
      case 'IGNORED':
        iconColor = AppColors.textMuted;
        iconBg = AppColors.backgroundLight;
        iconData = Icons.remove;
        break;
      default:
        iconColor = const Color(0xFF8E44AD);
        iconBg = const Color(0xFFF4ECF7);
        iconData = Icons.help_outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
