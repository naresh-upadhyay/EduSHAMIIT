import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/dashboard_model.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/app_header.dart';
import '../widgets/metric_card.dart';
import '../widgets/matched_payments_chart.dart';
import '../widgets/custom_date_range_dialog.dart';
import '../widgets/app_drawer.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _dashboardFuture;
  late Future<MatchedPaymentsAnalytics> _analyticsFuture;

  String _selectedTimeframe = 'today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  TimeOfDay? _customStartTime;
  TimeOfDay? _customEndTime;

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
    _analyticsFuture = ApiService().getMatchedPaymentsAnalytics(
      timeframe: _selectedTimeframe,
      startDate: _customStartDate != null ? _formatDateTimeIso(_customStartDate!, _customStartTime) : null,
      endDate: _customEndDate != null ? _formatDateTimeIso(_customEndDate!, _customEndTime) : null,
    );
  }

  String _formatDateTimeIso(DateTime d, TimeOfDay? t) {
    final hour = t?.hour ?? 0;
    final min = t?.minute ?? 0;
    final dt = DateTime(d.year, d.month, d.day, hour, min);
    return dt.toIso8601String();
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

  void _changeTimeframe(String tf) {
    if (tf == 'custom') {
      _pickCustomRange();
    } else {
      setState(() {
        _selectedTimeframe = tf;
        _analyticsFuture = ApiService().getMatchedPaymentsAnalytics(timeframe: tf);
      });
    }
  }

  Future<void> _pickCustomRange() async {
    final result = await CustomDateRangeDialog.show(
      context,
      initialStartDate: _customStartDate,
      initialEndDate: _customEndDate,
      initialStartTime: _customStartTime,
      initialEndTime: _customEndTime,
    );

    if (result == null) return;
    if (!mounted) return;

    setState(() {
      _selectedTimeframe = 'custom';
      _customStartDate = result.startDateTime;
      _customEndDate = result.endDateTime;
      _customStartTime = TimeOfDay(hour: result.startDateTime.hour, minute: result.startDateTime.minute);
      _customEndTime = TimeOfDay(hour: result.endDateTime.hour, minute: result.endDateTime.minute);

      _analyticsFuture = ApiService().getMatchedPaymentsAnalytics(
        timeframe: 'custom',
        startDate: _formatDateTimeIso(_customStartDate!, _customStartTime),
        endDate: _formatDateTimeIso(_customEndDate!, _customEndTime),
      );
    });
  }

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
          // App Header with Settings in top-right corner
          AppHeader(
            title: 'Payment Bridge',
            showRunningBadge: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Dashboard',
                onPressed: _refresh,
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
                      if (!_notificationAccessGranted)
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
                              const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Notification access disabled. Live payment capture paused.',
                                  style: TextStyle(fontSize: 12, color: AppColors.errorRed, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await PlatformBridge.openNotificationSettings();
                                  _checkListenerStatus();
                                },
                                child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.errorRed)),
                              ),
                            ],
                          ),
                        )
                      else if (!_isListenerActive)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.warningOrangeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.warningOrange, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Listener service inactive. Start it from Insights screen.',
                                  style: TextStyle(fontSize: 12, color: AppColors.warningOrange, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Card 1: Top 4 Metric Cards
                      _buildMetricCardsRow(data.metrics),
                      const SizedBox(height: 14),

                      // Card 2: Interactive Matched Payments Analytics & Graphs
                      _buildAnalyticsGraphCard(),
                      const SizedBox(height: 14),

                      // Card 3: Quick Navigation Shortcuts Row (Insights, Alerts, Transactions)
                      _buildQuickNavigationRow(),
                      const SizedBox(height: 14),

                      // Card 4: Sync Button
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

  Widget _buildMetricCardsRow(DashboardMetrics m) {
    return Row(
      children: [
        Expanded(
          child: DashboardMetricCard(
            label: 'Alerts\nToday',
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

  Widget _buildAnalyticsGraphCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: AppColors.primaryNavy, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Matched Payments Trend',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'RECONCILED',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.successGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timeframe Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeframeChip('today', 'Today (Hourly)'),
                const SizedBox(width: 6),
                _buildTimeframeChip('week', 'This Week'),
                const SizedBox(width: 6),
                _buildTimeframeChip('month', 'This Month'),
                const SizedBox(width: 6),
                _buildTimeframeChip('year', 'This Year'),
                const SizedBox(width: 6),
                _buildTimeframeChip('custom', _selectedTimeframe == 'custom' ? 'Custom Range ✓' : 'Custom Range ⚙'),
              ],
            ),
          ),

          // Custom Date Range Banner if active
          if (_selectedTimeframe == 'custom' && _customStartDate != null && _customEndDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 14, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${DateFormat('dd MMM yyyy').format(_customStartDate!)} - ${DateFormat('dd MMM yyyy').format(_customEndDate!)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  InkWell(
                    onTap: _pickCustomRange,
                    child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // FutureBuilder for Analytics Data
          FutureBuilder<MatchedPaymentsAnalytics>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const SizedBox(
                  height: 280,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryBlue),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading live payment analytics...',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final analytics = snapshot.data ?? MatchedPaymentsAnalytics.empty(_selectedTimeframe);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3 KPI Highlights
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniStat(
                          'Total Matched',
                          analytics.formattedVolume,
                          const Color(0xFF10A352),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStat(
                          'Verified Count',
                          '${analytics.matchedCount} txns',
                          AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniStat(
                          'Avg Ticket',
                          analytics.formattedAvgTicket,
                          const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // The Interactive Curve Chart
                  MatchedPaymentsChart(
                    points: analytics.chartData,
                    timeframe: _selectedTimeframe,
                  ),
                  const SizedBox(height: 16),

                  // App Source Distribution
                  if (analytics.matchedCount > 0 && analytics.appBreakdown.isNotEmpty) ...[
                    const Text(
                      'UPI Provider Breakdown',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _buildAppBreakdownBar(analytics.appBreakdown),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Text(
                            'No matched transactions in selected timeframe',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeChip(String key, String label) {
    final isSelected = _selectedTimeframe == key;
    return InkWell(
      onTap: () => _changeTimeframe(key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAppBreakdownBar(List<AppShareItem> items) {
    final validItems = items.where((it) => it.share > 0).toList();
    if (validItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Multi-color Segmented Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: validItems.map((item) {
              final color = Color(int.parse(item.colorHex.replaceFirst('#', '0xFF')));
              return Expanded(
                flex: item.share,
                child: Container(
                  height: 10,
                  color: color,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Legend Row
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: validItems.map((item) {
            final color = Color(int.parse(item.colorHex.replaceFirst('#', '0xFF')));
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  '${item.name} (${item.share}%)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickNavigationRow() {
    return Row(
      children: [
        Expanded(
          child: _buildNavCard(
            title: 'System Insights',
            subtitle: 'Device & Status',
            icon: Icons.insights_rounded,
            color: const Color(0xFF1E3A8A),
            onTap: () => widget.onNavigateTab(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavCard(
            title: 'Live Alerts',
            subtitle: 'Notification Feed',
            icon: Icons.notifications_active_outlined,
            color: const Color(0xFF5F259F),
            onTap: () => widget.onNavigateTab(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildNavCard(
            title: 'Transactions',
            subtitle: 'Matched Ledger',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF0F766E),
            onTap: () => widget.onNavigateTab(3),
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
