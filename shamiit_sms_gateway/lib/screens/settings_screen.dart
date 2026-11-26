import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';
import 'automation_rules_screen.dart';
import 'device_info_screen.dart';
import 'diagnostics_screen.dart';
import 'login_screen.dart';
import 'message_templates_screen.dart';
import 'privacy_policy_screen.dart';
import 'sim_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const SettingsScreen({super.key, this.onNavigateTab});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> _diag = {};
  Map<String, dynamic> _cfg = {};
  bool _notifyFailed = true;
  bool _notifyInbound = true;
  bool _notifySimChange = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final diag = await PlatformBridge.getDiagnostics();
    final cfgRes = await ApiService().getDeviceConfiguration();
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _cfg = (cfgRes['configuration'] as Map<String, dynamic>?) ?? {};
      _notifyFailed = prefs.getBool(AppConstants.prefsNotifyFailedKey) ?? true;
      _notifyInbound = prefs.getBool(AppConstants.prefsNotifyInboundKey) ?? true;
      _notifySimChange = prefs.getBool(AppConstants.prefsNotifySimChangeKey) ?? true;
    });
  }

  Future<void> _editServerUrl() async {
    final ctrl = TextEditingController(text: ApiService().displayServerHost);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AppDialogFrame(
          icon: Icons.dns_rounded,
          iconColor: AppColors.primaryBlue,
          title: 'Backend Server Configuration',
          subtitle: 'Select preset or enter custom FastAPI host',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Cloud (Live)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.liveServerBaseUrl),
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.localServerBaseUrlAndroid),
                  ),
                  ActionChip(
                    label: const Text('Localhost', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.localServerBaseUrlLoopback),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'FastAPI Server URL',
                  hintText: 'https://eduapi.shamiit.com',
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save & Test')),
          ],
        ),
      ),
    );
    if (newUrl == null || newUrl.trim().isEmpty) return;
    await ApiService().setServerUrl(newUrl);
    final ok = await ApiService().testConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Connected to ${ApiService().displayServerHost}' : 'Saved URL, but server is currently unreachable.'),
        backgroundColor: ok ? AppColors.successGreen : AppColors.warningOrange,
      ),
    );
    refresh();
  }

  void _showSecuritySheet() {
    final emergencyDisabled = _asBool(_cfg['emergency_disabled'], false);
    showAppBottomSheet(
      context: context,
      icon: Icons.security_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'Security & Access Control',
      subtitle: 'Device pairing, token rotation & emergency halt',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                InfoMetricRow(label: 'Device ID', value: ApiService().deviceId, monospace: true, showDivider: true),
                InfoMetricRow(
                  label: 'Keystore Encryption',
                  value: _diag['keystore_backed'] == true ? 'Yes (AES-256)' : 'Standard',
                  statusIcon: Icons.verified_user_rounded,
                  statusColor: _diag['keystore_backed'] == true ? AppColors.successGreen : AppColors.warningOrange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (sheetCtx) {
              final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
              return StatusCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isDark ? AppColors.purple.withValues(alpha: 0.18) : AppColors.purpleBg,
                        child: const Icon(Icons.key_rounded, color: AppColors.purple, size: 20),
                      ),
                      title: const Text('Renew Device Token', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Rotate cryptographic device auth token', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await ApiService().renewDeviceToken();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Device token rotated successfully'), backgroundColor: AppColors.successGreen),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Token renewal error: $e'), backgroundColor: AppColors.errorRed),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: CircleAvatar(
                        backgroundColor: isDark ? AppColors.errorRed.withValues(alpha: 0.18) : AppColors.errorRedBg,
                        child: const Icon(Icons.emergency_rounded, color: AppColors.errorRed, size: 20),
                      ),
                      title: const Text('Emergency Gateway Disable', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Immediately halt all outgoing SMS', style: TextStyle(fontSize: 12)),
                      value: emergencyDisabled,
                      onChanged: (v) async {
                        Navigator.pop(ctx);
                        await ApiService().setEmergencyDisable(v);
                        refresh();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (sheetCtx) {
              final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
              final errColor = isDark ? const Color(0xFFFF6B6B) : AppColors.errorRed;
              return SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.logout_rounded, color: errColor),
                  label: Text('Logout Session', style: TextStyle(color: errColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: errColor.withValues(alpha: 0.75)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ApiService().logout();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStorageSheet() {
    final dbBytes = (_diag['database_size_bytes'] as num?)?.toInt() ?? 0;
    final dbKb = (dbBytes / 1024).toStringAsFixed(1);
    final pendingUploads = (_diag['pending_uploads_count'] as num?)?.toInt() ?? 0;
    final pendingJobs = (_diag['pending_jobs_count'] as num?)?.toInt() ?? 0;

    showAppBottomSheet(
      context: context,
      icon: Icons.storage_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'Logs & Local Storage',
      subtitle: 'Offline SQLite queue and retention',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusCard(
            child: Column(
              children: [
                InfoMetricRow(label: 'Local Database Size', value: '$dbKb KB', showDivider: true),
                InfoMetricRow(label: 'Pending Uploads (Protected)', value: '$pendingUploads', showDivider: true),
                InfoMetricRow(label: 'Pending Leased Jobs', value: '$pendingJobs', showDivider: true),
                InfoMetricRow(label: 'Retention Window', value: '${_cfg['retention_days'] ?? 90} days'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined, size: 18),
            label: const Text('Clean Old Synced Logs'),
            onPressed: () async {
              final res = await PlatformBridge.cleanupLocalStorage(
                (_cfg['retention_days'] as num?)?.toInt() ?? 90,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pruned ${res['deleted_count'] ?? 0} old synced records')),
                );
                refresh();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet() {
    showAppBottomSheet(
      context: context,
      icon: Icons.notifications_active_outlined,
      iconColor: AppColors.warningOrange,
      title: 'Notification Preferences',
      subtitle: 'Control local alerts for gateway events',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => StatusCard(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Failed SMS Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Notify when an SMS fails permanently', style: TextStyle(fontSize: 12)),
                value: _notifyFailed,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(AppConstants.prefsNotifyFailedKey, v);
                  setSheet(() => _notifyFailed = v);
                  setState(() => _notifyFailed = v);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Incoming SMS Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Show alert when inbound SMS is received', style: TextStyle(fontSize: 12)),
                value: _notifyInbound,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(AppConstants.prefsNotifyInboundKey, v);
                  setSheet(() => _notifyInbound = v);
                  setState(() => _notifyInbound = v);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('SIM Change Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Notify if SIM slot or carrier changes', style: TextStyle(fontSize: 12)),
                value: _notifySimChange,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(AppConstants.prefsNotifySimChangeKey, v);
                  setSheet(() => _notifySimChange = v);
                  setState(() => _notifySimChange = v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGatewayAutomationSheet() {
    bool autoMsg = _asBool(_cfg['automated_messaging_enabled'], true);
    bool inboundFwd = _asBool(_cfg['incoming_forwarding_enabled'], true);
    bool queueSync = _asBool(_cfg['queue_sync_enabled'], true);
    bool schedProc = _asBool(_cfg['scheduled_processing_enabled'], true);
    int pollSec = (_cfg['polling_interval_seconds'] as num?)?.toInt() ?? 15;
    final nameCtrl = TextEditingController(
      text: (_cfg['device_name'] as String?) ?? (_diag['device_model'] as String?) ?? 'Android Gateway',
    );

    showAppBottomSheet(
      context: context,
      icon: Icons.tune_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'Gateway & Polling Engine',
      subtitle: 'Configure background sync & dispatch toggles',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Gateway Device Name'),
            ),
            const SizedBox(height: 12),
            StatusCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automated Messaging', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Dispatch queued jobs from FastAPI', style: TextStyle(fontSize: 11.5)),
                    value: autoMsg,
                    onChanged: (v) => setSheet(() => autoMsg = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Incoming SMS Forwarding', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Forward inbound SMS to backend & webhooks', style: TextStyle(fontSize: 11.5)),
                    value: inboundFwd,
                    onChanged: (v) => setSheet(() => inboundFwd = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Queue Synchronization', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    value: queueSync,
                    onChanged: (v) => setSheet(() => queueSync = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Scheduled Message Processing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    value: schedProc,
                    onChanged: (v) => setSheet(() => schedProc = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: [5, 10, 15, 30, 60, 120].contains(pollSec) ? pollSec : 15,
              decoration: const InputDecoration(labelText: 'Polling Interval'),
              items: const [
                DropdownMenuItem(value: 5, child: Text('Every 5 seconds')),
                DropdownMenuItem(value: 10, child: Text('Every 10 seconds')),
                DropdownMenuItem(value: 15, child: Text('Every 15 seconds (Default)')),
                DropdownMenuItem(value: 30, child: Text('Every 30 seconds')),
                DropdownMenuItem(value: 60, child: Text('Every 1 minute')),
                DropdownMenuItem(value: 120, child: Text('Every 2 minutes')),
              ],
              onChanged: (v) => setSheet(() => pollSec = v ?? 15),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save & Sync Settings'),
                onPressed: () async {
                  final ok = await ApiService().updateDeviceConfiguration({
                    'device_name': nameCtrl.text.trim(),
                    'automated_messaging_enabled': autoMsg,
                    'incoming_forwarding_enabled': inboundFwd,
                    'queue_sync_enabled': queueSync,
                    'scheduled_processing_enabled': schedProc,
                    'polling_interval_seconds': pollSec,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Gateway configuration saved & synced' : 'Saved locally (offline)'),
                        backgroundColor: ok ? AppColors.successGreen : AppColors.warningOrange,
                      ),
                    );
                    refresh();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _asBool(dynamic v, bool def) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return def;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ApiService().connectionState == GatewayConnectionState.online;

    return SkyHeaderContainer(
      child: Column(
        children: [
          const AppTopBar(title: 'Settings & Diagnostics', leadingTitleIcon: Icons.settings_rounded),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                StatusCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Image.asset(
                          'assets/images/shamiit_logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: AppColors.primaryBlue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SHAMIIT SMS Gateway',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                            ),
                            Text('Version ${AppConstants.appVersion}', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(status: isOnline ? 'ONLINE' : 'OFFLINE'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Gateway Configuration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 8),
                StatusCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.dns_rounded,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'Backend Server',
                        subtitle: ApiService().displayServerHost,
                        trailing: Icon(
                          isOnline ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isOnline ? AppColors.successGreen : AppColors.warningOrange,
                        ),
                        onTap: _editServerUrl,
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.tune_rounded,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'Gateway & Polling Engine',
                        subtitle: 'Auto messaging, forwarding & ${_cfg['polling_interval_seconds'] ?? 15}s interval',
                        onTap: _showGatewayAutomationSheet,
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.sim_card_rounded,
                        color: AppColors.successGreen,
                        bg: AppColors.successGreenBg,
                        title: 'SIM Configuration',
                        subtitle: 'Dual-SIM selection, fallback & usage mode',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimConfigScreen())),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.settings_suggest_rounded,
                        color: AppColors.purple,
                        bg: AppColors.purpleBg,
                        title: 'Automation Rules',
                        subtitle: 'Manage automated messaging rules',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationRulesScreen())),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.description_outlined,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'Message Templates',
                        subtitle: 'Manage reusable & DLT templates',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageTemplatesScreen())),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.battery_charging_full_rounded,
                        color: AppColors.successGreen,
                        bg: AppColors.successGreenBg,
                        title: 'Network & Battery Diagnostics',
                        subtitle: 'Network status, latency, battery & permissions',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.storage_rounded,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'Logs & Storage',
                        subtitle: 'Database size, pending queue & retention',
                        onTap: _showStorageSheet,
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.warningOrange,
                        bg: AppColors.warningOrangeBg,
                        title: 'Notifications',
                        subtitle: 'Failure, incoming SMS & SIM change alerts',
                        onTap: _showNotificationsSheet,
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'Security',
                        subtitle: 'Device pairing, token renewal & emergency stop',
                        onTap: _showSecuritySheet,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: CircleAvatar(
                          backgroundColor: isDark ? AppColors.purple.withValues(alpha: 0.18) : AppColors.purpleBg,
                          child: const Icon(Icons.dark_mode_outlined, color: AppColors.purple, size: 20),
                        ),
                        title: const Text('Dark Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        value: ThemeController.instance.isDark,
                        onChanged: (v) async {
                          ThemeController.instance.setDark(v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(AppConstants.prefsDarkModeKey, v);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        color: AppColors.primaryBlue,
                        bg: AppColors.primaryBlueLight,
                        title: 'About SHAMIIT & Device Info',
                        subtitle: 'App info, Play SMS policy & support',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceInfoScreen())),
                      ),
                      const Divider(height: 1),
                      _SettingsRow(
                        icon: Icons.privacy_tip_outlined,
                        color: AppColors.secondaryText,
                        bg: AppColors.background,
                        title: 'Privacy & Enterprise Distribution Policy',
                        subtitle: 'Compliance & permission disclosures',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                StatusCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/shamiit_logo.png',
                        width: 28,
                        height: 28,
                        errorBuilder: (_, __, ___) => const Icon(Icons.sms_rounded, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.tagline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: isDark ? Colors.lightBlueAccent : AppColors.darkBlue,
                              ),
                            ),
                            Text(
                              AppConstants.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
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
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDark ? color.withValues(alpha: 0.18) : bg,
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
      onTap: onTap,
    );
  }
}
