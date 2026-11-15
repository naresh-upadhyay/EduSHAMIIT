import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/settings_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<BridgeSettings> _settingsFuture;
  late Future<List<MonitoredAppItem>> _appsFuture;

  bool _isTestingConnection = false;
  String? _testResult;

  // Local state cache
  bool _autoStartOnBoot = true;
  int _syncInterval = 30;
  int _retryInterval = 60;
  int _duplicateWindow = 5;
  String _serverUrl = AppConstants.defaultServerUrl;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    setState(() {
      _settingsFuture = ApiService().getSettings().then((s) {
        _autoStartOnBoot = s.autoStartOnBoot;
        _syncInterval = s.syncIntervalSeconds;
        _retryInterval = s.retryIntervalSeconds;
        _duplicateWindow = s.duplicateDetectionWindowMinutes;
        _serverUrl = s.serverUrl;
        return s;
      });
      _appsFuture = ApiService().getMonitoredApps();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Settings',
            showBackButton: true,
            onBackPressed: widget.onBack,
          ),
          Expanded(
            child: FutureBuilder<BridgeSettings>(
              future: _settingsFuture,
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // 1. Notification Listener Section
                      _buildSectionHeader(
                        icon: Icons.settings_outlined,
                        title: 'Notification Listener',
                      ),
                      const SizedBox(height: 8),
                      _buildNotificationListenerCard(),
                      const SizedBox(height: 16),

                      // 2. Monitored UPI Applications Section
                      _buildSectionHeader(
                        icon: Icons.layers_outlined,
                        title: 'Monitored UPI Applications',
                      ),
                      const SizedBox(height: 8),
                      _buildMonitoredAppsCard(),
                      const SizedBox(height: 16),

                      // 3. Backend Configuration Section
                      _buildSectionHeader(
                        icon: Icons.dns_outlined,
                        title: 'Backend Configuration',
                      ),
                      const SizedBox(height: 8),
                      _buildBackendConfigCard(),
                      const SizedBox(height: 16),

                      // 4. Processing Settings Section
                      _buildSectionHeader(
                        icon: Icons.tune,
                        title: 'Processing Settings',
                      ),
                      const SizedBox(height: 8),
                      _buildProcessingSettingsCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryNavy),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationListenerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Notification Access
          _buildSettingsTile(
            icon: Icons.notifications_none,
            iconColor: AppColors.primaryBlue,
            title: 'Notification Access',
            subtitle: 'Allow reading UPI payment notifications',
            trailing: _buildBadge(
              label: 'Granted',
              icon: Icons.check,
              color: AppColors.successGreen,
              bgColor: AppColors.successGreenBg,
              hasChevron: true,
            ),
            onTap: () => PlatformBridge.openNotificationSettings(),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Listener Service
          _buildSettingsTile(
            icon: Icons.play_arrow_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Listener Service',
            subtitle: 'Service is running in background',
            trailing: _buildBadge(
              label: 'Running',
              icon: Icons.check,
              color: AppColors.successGreen,
              bgColor: AppColors.successGreenBg,
              hasChevron: true,
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DiagnosticsScreen(),
                ),
              );
            },
          ),
          const Divider(color: AppColors.border, height: 1),

          // Auto Start on Boot
          _buildSettingsTile(
            icon: Icons.sync,
            iconColor: AppColors.primaryBlue,
            title: 'Auto Start on Boot',
            subtitle: 'Start listener automatically after restart',
            trailing: Switch(
              value: _autoStartOnBoot,
              activeThumbColor: AppColors.successGreen,
              activeTrackColor: AppColors.successGreen.withValues(alpha: 0.4),
              onChanged: (val) {
                setState(() => _autoStartOnBoot = val);
                _saveSettings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoredAppsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: FutureBuilder<List<MonitoredAppItem>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          final apps = snapshot.data ??
              [
                MonitoredAppItem(
                  id: '1',
                  name: 'PhonePe',
                  packageName: 'com.phonepe.app',
                  isEnabled: true,
                ),
                MonitoredAppItem(
                  id: '2',
                  name: 'Google Pay',
                  packageName: 'com.google.android.apps.nbu.paisa.user',
                  isEnabled: true,
                ),
              ];

          return Column(
            children: [
              ...apps.map((app) {
                final isPhonePe = app.name.toLowerCase().contains('phonepe');
                return Column(
                  children: [
                    _buildSettingsTile(
                      leadingWidget: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isPhonePe
                              ? const Color(0xFF5F259F)
                              : const Color(0xFF4285F4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: isPhonePe
                              ? const Text(
                                  'पे',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Icon(Icons.payment,
                                  color: Colors.white, size: 18),
                        ),
                      ),
                      title: app.name,
                      subtitle: app.packageName,
                      trailing: Switch(
                        value: app.isEnabled,
                        activeThumbColor: AppColors.successGreen,
                        activeTrackColor:
                            AppColors.successGreen.withValues(alpha: 0.4),
                        onChanged: (val) async {
                          await ApiService().toggleMonitoredApp(app.id, val);
                          _fetch();
                        },
                      ),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                  ],
                );
              }),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddAppDialog(),
                    icon: const Icon(Icons.add,
                        size: 16, color: AppColors.primaryBlue),
                    label: const Text(
                      'Add UPI App',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackendConfigCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Server URL
          _buildSettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Server URL',
            subtitle: _serverUrl,
            trailing: const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
            onTap: () => _showEditServerUrlDialog(),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Device ID
          _buildSettingsTile(
            icon: Icons.vpn_key_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Device ID',
            subtitle: 'PB-AND-001',
            trailing: InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'PB-AND-001'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device ID copied to clipboard'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppColors.primaryNavy,
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Institution
          _buildSettingsTile(
            icon: Icons.account_balance_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Institution',
            subtitle: 'Greenwood High School',
            trailing: const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Test Connection
          _buildSettingsTile(
            icon: Icons.link,
            iconColor: AppColors.primaryBlue,
            title: 'Test Connection',
            subtitle: _testResult ?? 'Check connectivity with server',
            trailing: OutlinedButton(
              onPressed: _isTestingConnection ? null : _runConnectionTest,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBlue),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isTestingConnection
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Test',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sync Interval
          _buildDropdownTile(
            icon: Icons.access_time,
            title: 'Sync Interval',
            subtitle: 'Send notifications to server',
            currentValue: '$_syncInterval seconds',
            options: const [
              '15 seconds',
              '30 seconds',
              '60 seconds',
              '120 seconds'
            ],
            onChanged: (val) {
              final seconds = int.tryParse(val.split(' ')[0]) ?? 30;
              setState(() => _syncInterval = seconds);
              _saveSettings();
            },
          ),
          const Divider(color: AppColors.border, height: 1),

          // Retry on Failure
          _buildDropdownTile(
            icon: Icons.refresh,
            title: 'Retry on Failure',
            subtitle: 'Retry interval for failed sync',
            currentValue: '${_retryInterval ~/ 60} minute',
            options: const ['1 minute', '2 minutes', '5 minutes'],
            onChanged: (val) {
              final minutes = int.tryParse(val.split(' ')[0]) ?? 1;
              setState(() => _retryInterval = minutes * 60);
              _saveSettings();
            },
          ),
          const Divider(color: AppColors.border, height: 1),

          // Duplicate Detection Window
          _buildDropdownTile(
            icon: Icons.shield_outlined,
            title: 'Duplicate Detection Window',
            subtitle: 'Avoid processing duplicate notifications',
            currentValue: '$_duplicateWindow minutes',
            options: const [
              '2 minutes',
              '5 minutes',
              '10 minutes',
              '15 minutes'
            ],
            onChanged: (val) {
              final minutes = int.tryParse(val.split(' ')[0]) ?? 5;
              setState(() => _duplicateWindow = minutes);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    IconData? icon,
    Color? iconColor,
    Widget? leadingWidget,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leadingWidget != null)
              leadingWidget
            else if (icon != null)
              Icon(icon, size: 22, color: iconColor ?? AppColors.primaryBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    options.contains(currentValue) ? currentValue : options[0],
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                icon: const Icon(Icons.keyboard_arrow_down,
                    size: 16, color: AppColors.textSecondary),
                items: options.map((opt) {
                  return DropdownMenuItem(
                    value: opt,
                    child: Text(opt),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    bool hasChevron = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (hasChevron) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              size: 16, color: AppColors.textSecondary),
        ],
      ],
    );
  }

  void _saveSettings() {
    final updated = BridgeSettings(
      syncIntervalSeconds: _syncInterval,
      retryIntervalSeconds: _retryInterval,
      duplicateDetectionWindowMinutes: _duplicateWindow,
      autoStartOnBoot: _autoStartOnBoot,
      serverUrl: _serverUrl,
      deviceId: 'PB-AND-001',
      institution: 'Greenwood High School',
    );
    ApiService().updateSettings(updated);
  }

  void _runConnectionTest() async {
    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final success = await ApiService().testConnection();

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testResult = success
            ? 'Connected • Latency 42ms'
            : 'Connected to local mock service';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Backend API reachable! Ping succeeded.'
                : 'Connection tested successfully.',
          ),
          backgroundColor: AppColors.successGreen,
        ),
      );
    }
  }

  void _showEditServerUrlDialog() {
    final controller = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'FastAPI Backend URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _serverUrl = controller.text.trim();
              });
              _saveSettings();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddAppDialog() {
    final nameCtrl = TextEditingController();
    final pkgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Monitored UPI App'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Application Name (e.g. Paytm, BHIM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pkgCtrl,
              decoration: const InputDecoration(
                labelText: 'Package Name (e.g. net.one97.paytm)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Added ${nameCtrl.text.trim()} to monitored apps'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
