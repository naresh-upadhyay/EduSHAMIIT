import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/settings_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/dynamic_parser_studio_dialog.dart';
import 'diagnostics_screen.dart';
import 'login_screen.dart';

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
  String _serverUrl = AppConstants.livePaymentBridgeUrl;
  String _deviceId = '';
  String _institutionName = '';
  bool _notificationAccessGranted = false;
  bool _listenerRunning = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _checkNativeStatus();
  }

  Future<void> _checkNativeStatus() async {
    final granted = await PlatformBridge.hasNotificationAccess();
    final running = await PlatformBridge.isListenerRunning();
    if (mounted) {
      setState(() {
        _notificationAccessGranted = granted;
        _listenerRunning = running;
      });
    }
  }

  void _fetch() {
    setState(() {
      _deviceId = ApiService().deviceId;
      final inst = ApiService().institutionName;
      _institutionName = (inst.isNotEmpty && !inst.contains('Greenwood'))
          ? inst
          : 'Shami Innovation Academy';
      _serverUrl = ApiService().baseUrl;

      _settingsFuture = ApiService().getSettings().then((s) {
        _autoStartOnBoot = s.autoStartOnBoot;
        _syncInterval = s.syncIntervalSeconds;
        _retryInterval = s.retryIntervalSeconds;
        _duplicateWindow = s.duplicateDetectionWindowMinutes;
        return s;
      });
      _appsFuture = ApiService().getMonitoredApps();
    });
  }

  void _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Session'),
        content: const Text(
          'Are you sure you want to log out? Payment listening will continue locally, but sync to ERP will require re-authentication.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService().logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
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
                final bottomSafePadding = MediaQuery.of(context).padding.bottom;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    bottomSafePadding > 0 ? bottomSafePadding + 36 : 40,
                  ),
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

                      // 3. Backend Configuration Section (Strictly Authenticated)
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
                      const SizedBox(height: 16),

                      // 5. Advanced Parser Rules
                      _buildSectionHeader(
                        icon: Icons.format_paint_outlined,
                        title: 'Advanced Parser Formats',
                      ),
                      const SizedBox(height: 8),
                      _buildParserSettingsCard(),
                      const SizedBox(height: 20),

                      // 6. Account & Session Management
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout, size: 18, color: AppColors.errorRed),
                          label: const Text(
                            'Logout from Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.errorRed,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
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
      ),
      child: Column(
        children: [
          // Notification Access
          _buildSettingsTile(
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Notification Access',
            subtitle: _notificationAccessGranted
                ? 'Allow reading UPI payment notifications'
                : 'Permission required: Tap to grant in Android OS',
            trailing: _buildBadge(
              label: _notificationAccessGranted ? 'Granted' : 'Denied',
              icon: _notificationAccessGranted ? Icons.check : Icons.close,
              color: _notificationAccessGranted ? AppColors.successGreen : AppColors.errorRed,
              bgColor: _notificationAccessGranted ? AppColors.successGreenBg : AppColors.errorRedBg,
              hasChevron: true,
            ),
            onTap: () async {
              await PlatformBridge.openNotificationSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkNativeStatus();
            },
          ),
          const Divider(color: AppColors.border, height: 1),

          // Listener Service
          _buildSettingsTile(
            icon: Icons.play_arrow_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Listener Service',
            subtitle: _listenerRunning
                ? 'Service is running in background'
                : 'Service inactive (Auto-activates on notification)',
            trailing: _buildBadge(
              label: _listenerRunning ? 'Running' : 'Stopped',
              icon: _listenerRunning ? Icons.check : Icons.pause,
              color: _listenerRunning ? AppColors.successGreen : AppColors.warningOrange,
              bgColor: _listenerRunning ? AppColors.successGreenBg : AppColors.warningOrangeBg,
              hasChevron: true,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              );
            },
          ),
          const Divider(color: AppColors.border, height: 1),

          // Auto Start on Boot
          _buildSettingsTile(
            icon: Icons.restart_alt,
            iconColor: AppColors.primaryBlue,
            title: 'Auto Start on Boot',
            subtitle: 'Start listener automatically after restart',
            trailing: Switch(
              value: _autoStartOnBoot,
              activeThumbColor: AppColors.successGreen,
              activeTrackColor: AppColors.successGreen.withOpacity(0.4),
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
      ),
      child: FutureBuilder<List<MonitoredAppItem>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          final rawApps = snapshot.data;
          final apps = (rawApps != null && rawApps.isNotEmpty)
              ? rawApps
              : [
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
                  MonitoredAppItem(
                    id: '3',
                    name: 'Paytm',
                    packageName: 'net.one97.paytm',
                    isEnabled: true,
                  ),
                  MonitoredAppItem(
                    id: '4',
                    name: 'BHIM UPI',
                    packageName: 'in.org.npci.upiapp',
                    isEnabled: true,
                  ),
                ];

          return Column(
            children: [
              ...apps.map((app) {
                final isPhonePe = app.name.toLowerCase().contains('phonepe');
                final isGPay = app.name.toLowerCase().contains('google') || app.name.toLowerCase().contains('gpay');
                final isPaytm = app.name.toLowerCase().contains('paytm');
                final isBhim = app.name.toLowerCase().contains('bhim');

                Color iconBg = const Color(0xFF2563EB);
                Widget iconContent = const Icon(Icons.payment, color: Colors.white, size: 18);
                if (isPhonePe) {
                  iconBg = const Color(0xFF5F259F);
                  iconContent = const Text('पे', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
                } else if (isGPay) {
                  iconBg = const Color(0xFF4285F4);
                  iconContent = const Text('G', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
                } else if (isPaytm) {
                  iconBg = const Color(0xFF002E6E);
                  iconContent = const Text('P', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
                } else if (isBhim) {
                  iconBg = const Color(0xFF00796B);
                  iconContent = const Text('B', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
                }

                return Column(
                  children: [
                    _buildSettingsTile(
                      leadingWidget: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: iconContent),
                      ),
                      title: app.name,
                      subtitle: app.packageName,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: app.isEnabled,
                            activeThumbColor: AppColors.successGreen,
                            activeTrackColor: AppColors.successGreen.withOpacity(0.4),
                            onChanged: (val) async {
                              await ApiService().toggleMonitoredApp(app.id, val);
                              await PlatformBridge.setAppMonitored(app.packageName, val);
                              _fetch();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.errorRed),
                            tooltip: 'Remove App',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Remove App'),
                                  content: Text('Stop monitoring ${app.name}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ApiService().deleteMonitoredApp(app.id);
                                await PlatformBridge.setAppMonitored(app.packageName, false);
                                _fetch();
                              }
                            },
                          ),
                        ],
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
      ),
      child: Column(
        children: [
          // Server URL (Configurable)
          _buildSettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Server URL (Gateway / Cloud API)',
            subtitle: _serverUrl,
            trailing: InkWell(
              onTap: () => _showEditServerUrlDialog(),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      'Configure',
                      style: TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Device ID (Auto-generated & unique hardware bound)
          _buildSettingsTile(
            icon: Icons.vpn_key_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Unique Device ID (Auto Generated)',
            subtitle: _deviceId.isNotEmpty ? _deviceId : 'Detecting hardware ID...',
            trailing: InkWell(
              onTap: () {
                if (_deviceId.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: _deviceId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.primaryNavy,
                    ),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Institution (Auto fetched from account)
          _buildSettingsTile(
            icon: Icons.account_balance_outlined,
            iconColor: AppColors.primaryBlue,
            title: 'Institution (From Account)',
            subtitle: _institutionName,
            trailing: const Icon(Icons.verified, size: 16, color: AppColors.successGreen),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
      ),
      child: Column(
        children: [
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

  Widget _buildParserSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: FutureBuilder<List<MonitoredAppItem>>(
        future: _appsFuture,
        builder: (context, snapshot) {
          final List<Map<String, dynamic>> apps = [];
          final rawApps = snapshot.data;
          if (rawApps != null && rawApps.isNotEmpty) {
            for (final a in rawApps) {
              Color c = const Color(0xFF2563EB);
              final lower = a.name.toLowerCase();
              if (lower.contains('phonepe')) {
                c = const Color(0xFF5F259F);
              } else if (lower.contains('google') || lower.contains('gpay')) {
                c = const Color(0xFF4285F4);
              } else if (lower.contains('paytm')) {
                c = const Color(0xFF002E6E);
              } else if (lower.contains('bhim')) {
                c = const Color(0xFF00796B);
              } else if (lower.contains('cred')) {
                c = const Color(0xFF1B1B1B);
              }
              apps.add({'name': a.name, 'pkg': a.packageName, 'color': c});
            }
          } else {
            apps.addAll([
              {'name': 'PhonePe', 'pkg': 'com.phonepe.app', 'color': const Color(0xFF5F259F)},
              {'name': 'Google Pay', 'pkg': 'com.google.android.apps.nbu.paisa.user', 'color': const Color(0xFF4285F4)},
              {'name': 'Paytm', 'pkg': 'net.one97.paytm', 'color': const Color(0xFF002E6E)},
              {'name': 'BHIM UPI', 'pkg': 'in.org.npci.upiapp', 'color': const Color(0xFF00796B)},
              {'name': 'Cred', 'pkg': 'com.dreamplug.androidapp', 'color': const Color(0xFF1B1B1B)},
            ]);
          }

          if (!apps.any((a) => a['pkg'] == '*')) {
            apps.add({'name': 'All Other UPI Apps', 'pkg': '*', 'color': AppColors.primaryNavy});
          }

          return Column(
            children: [
              ...apps.map((a) {
                return Column(
                  children: [
                    _buildSettingsTile(
                      leadingWidget: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: a['color'] as Color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            (a['name'] as String)[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: a['name'] as String,
                      subtitle: a['pkg'] == '*' ? 'Default fallback parser' : a['pkg'] as String,
                      trailing: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Configure',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                      onTap: () => _showCustomFormatDialog(initialPkg: a['pkg'] as String),
                    ),
                    if (a != apps.last) const Divider(color: AppColors.border, height: 1),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showCustomFormatDialog({String initialPkg = 'com.phonepe.app'}) {
    DynamicParserStudioDialog.show(context, initialPackage: initialPkg, onSaved: _fetch);
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
                value: options.contains(currentValue) ? currentValue : options[0],
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
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
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
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
      deviceId: _deviceId,
      institution: _institutionName,
    );
    ApiService().updateSettings(updated);
  }

  void _runConnectionTest() async {
    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final stopwatch = Stopwatch()..start();
    final success = await ApiService().testConnection();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testResult = success
            ? 'Connected • Latency ${stopwatch.elapsedMilliseconds}ms'
            : 'Connection failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Backend API reachable! Ping succeeded.'
                : 'Connection failed: Server could not be reached.',
          ),
          backgroundColor: success ? AppColors.successGreen : AppColors.errorRed,
        ),
      );
    }
  }

  void _showAddAppDialog() {
    final nameCtrl = TextEditingController();
    final pkgCtrl = TextEditingController();
    bool isSaving = false;

    final presets = [
      {'name': 'PhonePe', 'pkg': 'com.phonepe.app'},
      {'name': 'Google Pay', 'pkg': 'com.google.android.apps.nbu.paisa.user'},
      {'name': 'Paytm', 'pkg': 'net.one97.paytm'},
      {'name': 'BHIM UPI', 'pkg': 'in.org.npci.upiapp'},
      {'name': 'Cred', 'pkg': 'com.dreamplug.androidapp'},
      {'name': 'Amazon Pay', 'pkg': 'in.amazon.mShop.android.shopping'},
      {'name': 'WhatsApp Pay', 'pkg': 'com.whatsapp'},
      {'name': 'Navi UPI', 'pkg': 'com.navi.mutualfunds'},
      {'name': 'Super.money', 'pkg': 'money.super.app'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Monitored UPI App', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick select popular UPI apps:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((p) {
                      final isSelected = pkgCtrl.text == p['pkg'];
                      return ChoiceChip(
                        label: Text(p['name']!, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                        onSelected: (val) {
                          setDialogState(() {
                            nameCtrl.text = p['name']!;
                            pkgCtrl.text = p['pkg']!;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Application Name (e.g. Cred, PhonePe)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pkgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Android Package Name (e.g. com.phonepe.app)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final pkg = pkgCtrl.text.trim();
                      if (name.isEmpty || pkg.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter application name and package name'),
                            backgroundColor: AppColors.errorRed,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      final ok = await ApiService().addMonitoredApp(name, pkg);
                      await PlatformBridge.setAppMonitored(pkg, true);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetch();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Saved $name to database & monitoring!'
                                : 'Added $name locally (server offline)'),
                            backgroundColor: ok ? AppColors.successGreen : Colors.orange,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(isSaving ? 'Saving...' : 'Add & Save to DB'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditServerUrlDialog() {
    final urlCtrl = TextEditingController(text: _serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Configure Backend Server URL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a preset or enter your PC LAN IP to connect from a physical mobile device:',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Local PC (WiFi)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'http://192.168.1.8:8082/api/v1/payment-bridge',
                  ),
                  ActionChip(
                    label: const Text('Cloud (Live)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'https://eduapi.shamiit.com/api/v1/payment-bridge',
                  ),
                  ActionChip(
                    label: const Text('Localhost (Web)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'http://localhost:8082/api/v1/payment-bridge',
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = 'http://10.0.2.2:8082/api/v1/payment-bridge',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Payment Bridge Server URL',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = urlCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(AppConstants.prefsServerUrlKey, newUrl);
                ApiService().updateConfig(baseUrl: newUrl);
                if (mounted) {
                  setState(() => _serverUrl = newUrl);
                  Navigator.pop(ctx);
                  _fetch();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Server URL updated to $newUrl'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save URL'),
          ),
        ],
      ),
    );
  }
}
