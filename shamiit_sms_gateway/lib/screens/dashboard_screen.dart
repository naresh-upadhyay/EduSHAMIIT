import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/common_components.dart';
import 'automation_rules_screen.dart';
import 'device_info_screen.dart';
import 'diagnostics_screen.dart';
import 'message_details_screen.dart';
import 'message_templates_screen.dart';
import 'send_sms_screen.dart';
import 'sim_config_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  const DashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  SmsStatistics _stats = SmsStatistics();
  List<SimInfo> _sims = [];
  List<SmsMessageRecord> _recentMessages = [];
  Map<String, dynamic> _diagnostics = {};
  Map<String, dynamic> _permissions = {};
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    refresh();
    _wsSub = WebSocketService().stream.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getSmsStatistics(),
        api.getSimConfiguration(),
        api.getSmsHistory(limit: 5),
        PlatformBridge.getDiagnostics(),
        PlatformBridge.getPermissionSnapshot(),
      ]);

      if (!mounted) return;
      final simCfg = results[1] as Map<String, dynamic>;
      setState(() {
        _stats = results[0] as SmsStatistics;
        _sims = (simCfg['sims'] as List<SimInfo>?) ?? [];
        _recentMessages = results[2] as List<SmsMessageRecord>;
        _diagnostics = results[3] as Map<String, dynamic>;
        _permissions = results[4] as Map<String, dynamic>;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _formatLastSync() {
    final dt = ApiService().lastSuccessfulSync ?? ApiService().lastSuccessfulRequest;
    if (dt == null) return 'Not synced yet';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    return '${diff.inHours} hr ago';
  }

  @override
  Widget build(BuildContext context) {
    final connState = ApiService().connectionState;
    final activeSim = _sims.where((s) => s.isActive).firstOrNull;
    final corePermsOk = _permissions['all_core_granted'] == true;

    return SkyHeaderContainer(
      blueHeader: true,
      child: Column(
        children: [
          AppTopBar(
            title: 'SHAMIIT SMS Gateway',
            isHomeHeader: true,
            lightForeground: true,
            actions: [
              IconButton(
                icon: Badge(
                  isLabelVisible: _stats.recentEvents.isNotEmpty,
                  backgroundColor: AppColors.errorRed,
                  label: Text('${_stats.recentEvents.length.clamp(0, 99)}'),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                ),
                onPressed: () => widget.onNavigateTab(2),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading SMS Gateway dashboard...')
                : _error != null && _recentMessages.isEmpty && _sims.isEmpty
                    ? ErrorState(message: _error!, onRetry: refresh)
                    : RefreshIndicator(
                        onRefresh: refresh,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            if (PlatformBridge.isAndroid && !corePermsOk) ...[
                              _PermissionWarningBanner(
                                onGrant: () async {
                                  await PlatformBridge.requestCorePermissions();
                                  await refresh();
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildGatewayStatusCard(connState, activeSim),
                            const SizedBox(height: 12),
                            _buildActiveDeviceCard(activeSim),
                            const SizedBox(height: 12),
                            _buildStatsGrid(),
                            const SizedBox(height: 16),
                            _buildSimSection(),
                            const SizedBox(height: 16),
                            _buildQuickActions(),
                            const SizedBox(height: 18),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayStatusCard(GatewayConnectionState connState, SimInfo? activeSim) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color badgeColor;
    Color bgTint;
    IconData icon;
    String statusTitle;
    switch (connState) {
      case GatewayConnectionState.online:
        badgeColor = AppColors.successGreen;
        bgTint = AppColors.successGreenBg;
        icon = Icons.check_circle_rounded;
        statusTitle = 'Gateway Online';
        break;
      case GatewayConnectionState.connecting:
        badgeColor = AppColors.warningOrange;
        bgTint = AppColors.warningOrangeBg;
        icon = Icons.sync_rounded;
        statusTitle = 'Connecting...';
        break;
      case GatewayConnectionState.authError:
        badgeColor = AppColors.errorRed;
        bgTint = AppColors.errorRedBg;
        icon = Icons.lock_outline_rounded;
        statusTitle = 'Authentication Error';
        break;
      case GatewayConnectionState.offline:
        badgeColor = AppColors.errorRed;
        bgTint = AppColors.errorRedBg;
        icon = Icons.cloud_off_rounded;
        statusTitle = 'Gateway Offline';
        break;
    }

    return StatusCard(
      backgroundColor: isDark ? badgeColor.withValues(alpha: 0.14) : bgTint,
      borderColor: badgeColor.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Last Sync: ${_formatLastSync()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Server: ${ApiService().displayServerHost}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sync Now',
            icon: Icon(Icons.refresh_rounded, color: badgeColor),
            onPressed: () async {
              await ApiService().syncNow();
              await refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDeviceCard(SimInfo? activeSim) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final model = (_diagnostics['device_model'] as String?) ?? 'Android Gateway';
    final simText = activeSim != null
        ? '${activeSim.slotLabel} • ${activeSim.carrierName}'
        : 'No active SIM detected';

    return StatusCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeviceInfoScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smartphone_rounded, color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Active Device',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      simText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    if (activeSim != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SignalBars(level: activeSim.signalLevel),
                          const SizedBox(width: 4),
                          Text(
                            '${activeSim.signalLabel} Signal',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final fmt = NumberFormat.decimalPattern();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.send_rounded,
                iconColor: AppColors.primaryBlue,
                iconBgColor: Colors.white.withValues(alpha: 0.85),
                cardTint: const Color(0xFFF0F6FF),
                value: fmt.format(_stats.sentToday),
                label: 'Sent Today',
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                icon: Icons.inbox_rounded,
                iconColor: AppColors.successGreen,
                iconBgColor: Colors.white.withValues(alpha: 0.85),
                cardTint: const Color(0xFFEEFBF4),
                value: fmt.format(_stats.receivedToday),
                label: 'Received Today',
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                icon: Icons.check_circle_rounded,
                iconColor: AppColors.successGreen,
                iconBgColor: Colors.white.withValues(alpha: 0.85),
                cardTint: const Color(0xFFEEFBF4),
                value: '${_stats.deliveryRate.toStringAsFixed(1)}%',
                label: 'Delivered (${fmt.format(_stats.deliveredToday)})',
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                icon: Icons.error_rounded,
                iconColor: AppColors.errorRed,
                iconBgColor: Colors.white.withValues(alpha: 0.85),
                cardTint: const Color(0xFFFEF1F1),
                value: fmt.format(_stats.failedToday),
                label: 'Failed',
                onTap: () => widget.onNavigateTab(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Detected SIM Cards',
          actionLabel: 'Configure →',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SimConfigScreen()),
          ).then((_) => refresh()),
        ),
        if (_sims.isEmpty)
          StatusCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SimConfigScreen()),
            ).then((_) => refresh()),
            child: const Row(
              children: [
                Icon(Icons.sim_card_alert_outlined, color: AppColors.warningOrange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No SIM cards detected yet. Grant Phone/SMS permissions or insert a SIM card.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            children: _sims.asMap().entries.map((entry) {
              final sim = entry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: entry.key < _sims.length - 1 ? 10 : 0),
                  child: SimCard(
                    sim: sim,
                    selected: sim.isActive && entry.key == 0,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SimConfigScreen()),
                    ).then((_) => refresh()),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Quick Actions',
          actionLabel: 'See All →',
          onAction: _showAllQuickActionsSheet,
        ),
        Row(
          children: [
            _QuickActionTile(
              icon: Icons.send_rounded,
              color: AppColors.primaryBlue,
              bg: AppColors.primaryBlueLight,
              label: 'Send\nSMS',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SendSmsScreen()),
              ).then((_) => refresh()),
            ),
            const SizedBox(width: 8),
            _QuickActionTile(
              icon: Icons.sim_card_rounded,
              color: AppColors.successGreen,
              bg: AppColors.successGreenBg,
              label: 'SIM\nSettings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SimConfigScreen()),
              ).then((_) => refresh()),
            ),
            const SizedBox(width: 8),
            _QuickActionTile(
              icon: Icons.settings_suggest_rounded,
              color: AppColors.purple,
              bg: AppColors.purpleBg,
              label: 'Auto\nRules',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AutomationRulesScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _QuickActionTile(
              icon: Icons.list_alt_rounded,
              color: AppColors.warningOrange,
              bg: AppColors.warningOrangeBg,
              label: 'SMS\nLogs',
              onTap: () => widget.onNavigateTab(1),
            ),
          ],
        ),
      ],
    );
  }

  void _showAllQuickActionsSheet() {
    showAppBottomSheet(
      context: context,
      icon: Icons.apps_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'All Gateway Actions',
      subtitle: 'Quickly jump to any SMS Gateway workspace',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _SheetActionCard(
                icon: Icons.send_rounded,
                color: AppColors.primaryBlue,
                title: 'Send SMS',
                subtitle: 'Compose & schedule',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SendSmsScreen()));
                },
              ),
              const SizedBox(width: 10),
              _SheetActionCard(
                icon: Icons.sim_card_rounded,
                color: AppColors.successGreen,
                title: 'SIM Config',
                subtitle: 'Routing & fallback',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SimConfigScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SheetActionCard(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.purple,
                title: 'Automation',
                subtitle: 'Triggers & webhooks',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationRulesScreen()));
                },
              ),
              const SizedBox(width: 10),
              _SheetActionCard(
                icon: Icons.description_outlined,
                color: AppColors.primaryBlue,
                title: 'Templates',
                subtitle: 'DLT & variables',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageTemplatesScreen()));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SheetActionCard(
                icon: Icons.bar_chart_rounded,
                color: AppColors.warningOrange,
                title: 'Monitor',
                subtitle: 'Live telemetry',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onNavigateTab(2);
                },
              ),
              const SizedBox(width: 10),
              _SheetActionCard(
                icon: Icons.health_and_safety_outlined,
                color: AppColors.errorRed,
                title: 'Diagnostics',
                subtitle: 'API & permissions',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recent Activity',
          actionLabel: 'See All →',
          onAction: () => widget.onNavigateTab(1),
        ),
        if (_recentMessages.isEmpty)
          const StatusCard(
            child: EmptyState(
              icon: Icons.sms_outlined,
              title: 'No Recent SMS Activity',
              subtitle: 'Sent and received SMS events will appear here automatically.',
            ),
          )
        else
          ..._recentMessages.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MessageListItem(
                message: m,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessageDetailsScreen(messageUuid: m.messageUuid, initialRecord: m),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SheetActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: StatusCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: StatusCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.18) : bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionWarningBanner extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionWarningBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StatusCard(
      backgroundColor: isDark ? AppColors.warningOrange.withValues(alpha: 0.16) : AppColors.warningOrangeBg,
      borderColor: AppColors.warningOrange.withValues(alpha: 0.4),
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: AppColors.warningOrange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'SMS & Phone permissions are required for SIM discovery and sending/receiving SMS.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onGrant,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Grant', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
