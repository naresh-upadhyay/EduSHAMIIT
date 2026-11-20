import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/analytics_model.dart';
import '../services/api_service.dart';
import '../screens/login_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/settings_screen.dart';
import 'dynamic_parser_studio_dialog.dart';

class AppDrawer extends StatefulWidget {
  final Function(int)? onSelectTab;

  const AppDrawer({super.key, this.onSelectTab});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Map<String, String> _userProfile = {
    'name': 'Naresh King',
    'email': 'admin@shamiit.com',
    'role': 'Enterprise Admin',
    'institution': 'SHAMIIT Technologies',
  };
  DrawerTotals _drawerTotals = DrawerTotals.fallback();
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  Future<void> _loadDrawerData() async {
    try {
      final profile = await ApiService().getUserProfile();
      final analytics = await ApiService().getMatchedPaymentsAnalytics(timeframe: 'today');
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _drawerTotals = analytics.drawerTotals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await ApiService().triggerSync();
      await _loadDrawerData();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(success ? 'Sync completed successfully!' : 'Sync finished.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final navigator = Navigator.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out from this SHAMIIT Payment Bridge terminal?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().logout();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userProfile['name'] ?? 'Naresh King';
    final email = _userProfile['email'] ?? 'admin@shamiit.com';
    final institution = _userProfile['institution'] ?? 'SHAMIIT Technologies';
    final role = _userProfile['role'] ?? 'Enterprise Admin';
    final photoUrl = _userProfile['photo_url'];

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drawer Header with User Profile
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.headerGradientStart,
                    AppColors.headerGradientEnd,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // User Avatar: User Profile Photo if present, else Company Logo
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: (photoUrl != null && photoUrl.trim().isNotEmpty)
                              ? Image.network(
                                  photoUrl.trim(),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Image.asset(
                                    'assets/images/shamiit_logo.png',
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/shamiit_logo.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.primaryNavy,
                                    size: 28,
                                  ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Organization & Role Chips
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_rounded, color: Colors.white70, size: 12),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                institution,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2, color: AppColors.primaryBlue),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Section: Successfully Matched Payment Totals
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 15, color: AppColors.successGreen),
                            SizedBox(width: 6),
                            Text(
                              'MATCHED PAYMENTS RECEIVED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // 3 Cards: Today, This Month, This Year
                        _buildMatchedCard(
                          title: "Today's Matched",
                          amount: _drawerTotals.todayFormatted,
                          count: '${_drawerTotals.todayCount} verified',
                          gradient: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                          icon: Icons.today_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildMatchedCard(
                          title: 'This Month',
                          amount: _drawerTotals.monthFormatted,
                          count: '${_drawerTotals.monthCount} verified',
                          gradient: const [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          icon: Icons.calendar_month_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildMatchedCard(
                          title: 'This Year (2026)',
                          amount: _drawerTotals.yearFormatted,
                          count: '${_drawerTotals.yearCount} verified',
                          gradient: const [Color(0xFF065F46), Color(0xFF059669)],
                          icon: Icons.account_balance_rounded,
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 20, color: AppColors.border),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'PREFERENCES & SYSTEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),

                  _buildDrawerTile(
                    icon: Icons.tune_rounded,
                    title: 'Dynamic Message Parser',
                    subtitle: 'Quality gates & regex extractors',
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => const DynamicParserStudioDialog(),
                      );
                    },
                  ),

                  _buildDrawerTile(
                    icon: Icons.phonelink_setup_rounded,
                    title: 'Device Diagnostics',
                    subtitle: 'Hardware, battery & sync stats',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                      );
                    },
                  ),

                  _buildDrawerTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings & Config',
                    subtitle: 'Monitored apps & server endpoint',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),

                  _buildDrawerTile(
                    icon: Icons.security_rounded,
                    title: 'Privacy Policy & Compliance',
                    subtitle: 'DPDP Act & on-device data policy',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Drawer Footer: Sync Now & Logout
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Sync Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryNavy),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isSyncing ? null : _handleSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryNavy),
                                )
                              : const Icon(Icons.sync_rounded, size: 18, color: AppColors.primaryNavy),
                          label: Text(
                            _isSyncing ? 'Syncing...' : 'Sync Now',
                            style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Logout Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: AppColors.errorRed,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.errorRed),
                          label: const Text(
                            'Logout',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SHAMIIT Technologies • shamiit.com',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchedCard({
    required String title,
    required String amount,
    required String count,
    required List<Color> gradient,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.primaryNavy),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
