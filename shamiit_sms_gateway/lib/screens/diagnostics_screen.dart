import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  Map<String, dynamic> _diag = {};
  bool _isLoading = true;
  bool _pingOk = false;
  int? _latencyMs;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final diag = await PlatformBridge.getDiagnostics();
    final ok = await ApiService().testConnection();
    final latency = ApiService().lastApiLatencyMs;
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _pingOk = ok;
      _latencyMs = latency;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final perms = (_diag['permissions'] as Map<dynamic, dynamic>?) ?? {};
    final battery = (_diag['battery_level'] as num?)?.toInt() ?? 0;
    final charging = _diag['is_charging'] == true;
    final batteryOptDisabled = _diag['battery_optimization_disabled'] == true;
    final serviceRunning = _diag['service_running'] == true;
    final internetConnected = _diag['internet_connected'] == true;
    final coreHealthy = _pingOk &&
        internetConnected &&
        serviceRunning &&
        perms['send_sms'] == true &&
        perms['receive_sms'] == true &&
        perms['read_phone_state'] == true;

    final heroColor = coreHealthy ? AppColors.successGreen : AppColors.warningOrange;
    final heroBg = isDark
        ? heroColor.withValues(alpha: 0.14)
        : (coreHealthy ? AppColors.successGreenBg : AppColors.warningOrangeBg);

    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'Diagnostics',
              showBackButton: true,
              actions: [
                IconButton(
                  tooltip: 'Re-run Diagnostics',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refresh,
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Running hardware & API diagnostics...')
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          // Summary Hero Card
                          StatusCard(
                            backgroundColor: heroBg,
                            borderColor: heroColor.withValues(alpha: 0.32),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: heroColor,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    coreHealthy ? Icons.verified_rounded : Icons.health_and_safety_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        coreHealthy ? 'All Gateway Systems Healthy' : 'Attention Recommended',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _pingOk
                                            ? 'API latency ${_latencyMs ?? 0} ms • ${serviceRunning ? 'Service active' : 'Service stopped'}'
                                            : 'Backend unreachable • Check server URL or network',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Backend & Network
                          StatusCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardTitle(
                                  icon: Icons.dns_rounded,
                                  color: AppColors.primaryBlue,
                                  title: 'Backend & Network',
                                  trailing: StatusBadge(status: _pingOk ? 'CONNECTED' : 'UNREACHABLE'),
                                ),
                                const SizedBox(height: 10),
                                InfoMetricRow(
                                  label: 'API Connectivity',
                                  value: _pingOk ? 'Connected (${_latencyMs ?? 0} ms)' : 'Unreachable',
                                  statusIcon: _pingOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  statusColor: _pingOk ? AppColors.successGreen : AppColors.errorRed,
                                  showDivider: true,
                                ),
                                InfoMetricRow(
                                  label: 'Server Endpoint',
                                  value: ApiService().displayServerHost,
                                  monospace: true,
                                  showDivider: true,
                                ),
                                InfoMetricRow(
                                  label: 'Internet Transport',
                                  value: (_diag['network_type'] ?? 'Unknown').toString(),
                                  statusIcon: internetConnected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  statusColor: internetConnected ? AppColors.successGreen : AppColors.warningOrange,
                                  showDivider: true,
                                ),
                                InfoMetricRow(
                                  label: 'Gateway Service',
                                  value: serviceRunning ? 'Running' : 'Stopped',
                                  statusIcon: serviceRunning ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  statusColor: serviceRunning ? AppColors.successGreen : AppColors.warningOrange,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          await PlatformBridge.startGatewayService();
                                          _refresh();
                                        },
                                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                        label: const Text(
                                          'Start Service',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          await ApiService().syncNow();
                                          _refresh();
                                        },
                                        icon: const Icon(Icons.sync_rounded, size: 18),
                                        label: const Text(
                                          'Sync Queue',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Runtime Permissions
                          StatusCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardTitle(
                                  icon: Icons.verified_user_outlined,
                                  color: AppColors.purple,
                                  title: 'Runtime Permissions',
                                  trailing: StatusBadge(
                                    status: (perms['send_sms'] == true &&
                                            perms['receive_sms'] == true &&
                                            perms['read_phone_state'] == true)
                                        ? 'GRANTED'
                                        : 'PAUSED',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _permRow('SEND_SMS', perms['send_sms'] == true),
                                _permRow('RECEIVE_SMS', perms['receive_sms'] == true),
                                _permRow('READ_PHONE_STATE', perms['read_phone_state'] == true),
                                _permRow('POST_NOTIFICATIONS', perms['post_notifications'] == true),
                                _permRow('READ_CONTACTS (Optional)', perms['read_contacts'] == true, optional: true),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          await PlatformBridge.requestCorePermissions();
                                          _refresh();
                                        },
                                        icon: const Icon(Icons.security_rounded, size: 17),
                                        label: const Text(
                                          'Grant Perms',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: PlatformBridge.openAppSettings,
                                        icon: const Icon(Icons.tune_rounded, size: 17),
                                        label: const Text(
                                          'App Settings',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Battery & Background Execution
                          StatusCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CardTitle(
                                  icon: Icons.battery_charging_full_rounded,
                                  color: AppColors.successGreen,
                                  title: 'Battery & Background',
                                  trailing: StatusBadge(
                                    status: batteryOptDisabled ? 'UNRESTRICTED' : 'RESTRICTED',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                InfoMetricRow(
                                  label: 'Battery Level',
                                  value: '$battery% (${charging ? 'Charging' : 'On Battery'})',
                                  statusIcon: (battery > 20 || charging)
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  statusColor: (battery > 20 || charging)
                                      ? AppColors.successGreen
                                      : AppColors.warningOrange,
                                  showDivider: true,
                                ),
                                InfoMetricRow(
                                  label: 'Battery Optimization',
                                  value: batteryOptDisabled ? 'Unrestricted' : 'Restricted',
                                  statusIcon: batteryOptDisabled
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  statusColor: batteryOptDisabled
                                      ? AppColors.successGreen
                                      : AppColors.warningOrange,
                                ),
                                if (!batteryOptDisabled) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await PlatformBridge.requestIgnoreBatteryOptimizations();
                                        _refresh();
                                      },
                                      icon: const Icon(Icons.battery_saver_rounded, size: 18),
                                      label: const Text(
                                        'Disable Battery Optimization',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                        : AppColors.primaryBlueLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 17, color: AppColors.primaryBlue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'If the app is force-stopped by the user or an OEM task killer, Android pauses background SMS receivers until the app is reopened.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.4,
                                            color: isDark ? AppColors.darkSecondaryText : AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permRow(String perm, bool granted, {bool optional = false}) {
    return InfoMetricRow(
      label: perm,
      value: granted ? 'Granted' : (optional ? 'Not Requested' : 'Denied'),
      statusIcon: granted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
      statusColor: granted ? AppColors.successGreen : AppColors.warningOrange,
      showDivider: !optional,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget? trailing;

  const _CardTitle({
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
