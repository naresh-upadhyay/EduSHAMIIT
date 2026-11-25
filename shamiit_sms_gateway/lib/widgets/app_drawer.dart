import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../screens/automation_rules_screen.dart';
import '../screens/device_info_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/login_screen.dart';
import '../screens/message_templates_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/send_sms_screen.dart';
import '../screens/sim_config_screen.dart';
import '../services/api_service.dart';
import 'common_components.dart';

class AppDrawer extends StatefulWidget {
  final Function(int)? onSelectTab;

  const AppDrawer({super.key, this.onSelectTab});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, String> _userProfile = {
    'name': 'Gateway Admin',
    'email': 'admin@shamiit.com',
    'role': 'Enterprise Admin',
    'institution': 'Shami Innovation Academy',
  };
  SmsStatistics _stats = SmsStatistics();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  Future<void> _loadDrawerData() async {
    try {
      final profile = await ApiService().getUserProfile();
      final stats = await ApiService().getSmsStatistics();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _stats = stats;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      await ApiService().syncNow();
      await _loadDrawerData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gateway synchronized successfully'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync warning: $e'), backgroundColor: AppColors.errorRed),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out from this SHAMIIT SMS GATEWAY terminal?',
      confirmLabel: 'Logout',
      confirmColor: AppColors.errorRed,
    );
    if (!confirmed || !mounted) return;
    await ApiService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile['name'] ?? 'Gateway Admin';
    final email = _userProfile['email'] ?? 'admin@shamiit.com';
    final institution = _userProfile['institution'] ?? 'Shami Innovation Academy';
    final role = _userProfile['role'] ?? 'Admin';
    final photoUrl = _userProfile['photo_url'] ?? '';

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.darkBlue, AppColors.primaryBlue],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: photoUrl.isNotEmpty
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Image.asset('assets/images/shamiit_logo.png', fit: BoxFit.contain),
                                )
                              : Image.asset(
                                  'assets/images/shamiit_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.sms_rounded, color: AppColors.primaryBlue),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${role.toUpperCase()} • $institution',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat('Sent', _stats.sentToday.toString()),
                        _MiniStat('Received', _stats.receivedToday.toString()),
                        _MiniStat('Delivered', '${_stats.deliveryRate.toStringAsFixed(0)}%'),
                        _MiniStat('Failed', _stats.failedToday.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    title: 'Dashboard (Home)',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelectTab?.call(0);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.sim_card_rounded,
                    title: 'SIM Configuration',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SimConfigScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.send_rounded,
                    title: 'Send SMS',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SendSmsScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'SMS Logs',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelectTab?.call(1);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.analytics_rounded,
                    title: 'Real-Time Monitoring',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelectTab?.call(2);
                    },
                  ),
                  const Divider(height: 16),
                  _DrawerItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Automation Rules',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationRulesScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    title: 'Message Templates',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageTemplatesScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.phonelink_setup_rounded,
                    title: 'Device Information',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceInfoScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Diagnostics',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelectTab?.call(3);
                    },
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: _isSyncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, color: AppColors.primaryBlue),
                    title: const Text('Sync Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Device: ${ApiService().deviceId}', style: const TextStyle(fontSize: 11)),
                    onTap: _isSyncing ? null : _handleSync,
                  ),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & SMS Policy',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.errorRed),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                '${AppConstants.companyName} • v${AppConstants.appVersion}',
                style: TextStyle(fontSize: 10.5),
              ),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String val;
  const _MiniStat(this.label, this.val);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.primaryBlue, size: 22),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      onTap: onTap,
    );
  }
}
