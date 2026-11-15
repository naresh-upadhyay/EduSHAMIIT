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

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _dashboardFuture;
  bool _isListenerActive = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    WebSocketService().stream.listen((event) {
      if (mounted) {
        setState(() {
          _dashboardFuture = ApiService().getDashboardData();
        });
      }
    });
  }

  void _refresh() {
    setState(() {
      _dashboardFuture = ApiService().getDashboardData();
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
    await Future.delayed(const Duration(milliseconds: 600));
    _refresh();
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
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'diagnostics',
                    child: Text('Device Diagnostics'),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Text('Refresh Data'),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<DashboardData>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                final data = snapshot.data ?? DashboardData.mock();
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Payment Listener Active Switch Card
                        _buildListenerActiveCard(data),
                        const SizedBox(height: 12),

                        // 2. 4 Metric Cards in horizontal row
                        _buildMetricCardsRow(data.metrics),
                        const SizedBox(height: 14),

                        // 3. System Status Card
                        _buildSystemStatusCard(data.systemStatus),
                        const SizedBox(height: 14),

                        // 4. Today's Activity Card
                        _buildTodayActivityCard(data.todayActivity),
                        const SizedBox(height: 16),

                        // 5. Sync Now Button & Timestamp Caption
                        _buildSyncNowSection(data.metrics.lastSyncTime),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
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
                color: const Color(0xFFE8F8EE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFB7E4C7)),
              ),
              child: const Icon(
                Icons.phone_android,
                color: Color(0xFF10A352),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Listener Active',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Monitoring UPI payment notifications',
                    style: TextStyle(
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
              onChanged: (val) {
                setState(() => _isListenerActive = val);
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
            icon: Icons.warning_amber_rounded,
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
              badgeText: s.notificationAccess,
              onTap: () => PlatformBridge.openNotificationSettings(),
            ),
            const Divider(color: AppColors.divider, height: 16),
            _buildStatusRow(
              icon: Icons.grid_view_rounded,
              title: 'Monitored UPI Apps',
              badgeText: s.monitoredUpiApps,
              onTap: () => widget.onNavigateTab(3), // Navigate to settings
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.check, color: AppColors.successGreen, size: 14),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.successGreen,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _buildTodayActivityCard(List<ActivityItem> activities) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart,
                        color: AppColors.primaryBlue, size: 20),
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
                InkWell(
                  onTap: () => widget.onNavigateTab(1), // Go to Notifications
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: AppColors.primaryBlue, size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No activity recorded yet today.'),
              )
            else
              ...activities.map((a) => _buildActivityTile(a)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(ActivityItem item) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    if (item.iconType == 'SUCCESS') {
      icon = Icons.check;
      iconColor = AppColors.successGreen;
      iconBg = AppColors.successGreenBg;
    } else if (item.iconType == 'WARNING') {
      icon = Icons.priority_high;
      iconColor = AppColors.warningOrange;
      iconBg = AppColors.warningOrangeBg;
    } else {
      icon = Icons.schedule;
      iconColor = AppColors.pendingBlue;
      iconBg = AppColors.pendingBlueBg;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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

  Widget _buildSyncNowSection(String lastSyncTime) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleSyncNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
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
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Last successful sync: $lastSyncTime',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
