import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/settings_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentSettings extends ConsumerWidget {
  const ParentSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: ResponsiveContent(
              child: ListView(
                padding: Responsive.contentPadding(context)
                    .copyWith(top: 16, bottom: 16),
                children: [
                  // ── Notifications ──
                  _sectionTitle('Notifications'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _toggleTile(
                    'Push Notifications'.tr(ref),
                    'Receive alerts about your child'.tr(ref),
                    settings?.pushNotifications ?? true,
                    Icons.notifications_active,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('pushNotifications', v),
                  ),
                  _toggleTile(
                    'SMS Alerts'.tr(ref),
                    'Get SMS for urgent updates'.tr(ref),
                    settings?.smsAlerts ?? true,
                    Icons.sms,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('smsAlerts', v),
                  ),
                  _toggleTile(
                    'Email Reports'.tr(ref),
                    'Weekly progress via email'.tr(ref),
                    settings?.emailReports ?? false,
                    Icons.email,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('emailReports', v),
                  ),
                  const SizedBox(height: 20),

                  // ── Appearance ──
                  _sectionTitle('Appearance'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _toggleTile(
                    'Dark Mode'.tr(ref),
                    'Switch to dark theme'.tr(ref),
                    settings?.darkMode ?? false,
                    Icons.dark_mode,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('darkMode', v),
                  ),
                  const SizedBox(height: 20),

                  // ── Security ──
                  _sectionTitle('Security'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _toggleTile(
                    'Biometric Login'.tr(ref),
                    'Use fingerprint/face to login'.tr(ref),
                    settings?.biometricLogin ?? true,
                    Icons.fingerprint,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('biometricLogin', v),
                  ),
                  _toggleTile(
                    'AI Personalization'.tr(ref),
                    'Allow AI to personalize content'.tr(ref),
                    settings?.aiPersonalization ?? true,
                    Icons.smart_toy,
                    isDark,
                    (v) => ref
                        .read(settingsProvider.notifier)
                        .updateSetting('aiPersonalization', v),
                  ),
                  const SizedBox(height: 20),

                  // ── Account ──
                  _sectionTitle('Account'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _actionTile(
                    'Change Password'.tr(ref),
                    Icons.lock_outline,
                    isDark,
                    () {
                      // Navigate to change password
                    },
                  ),
                  _actionTile(
                    'Delete Account'.tr(ref),
                    Icons.delete_outline,
                    isDark,
                    () {
                      _showDeleteConfirmDialog(context, ref);
                    },
                    isDestructive: true,
                  ),
                  const SizedBox(height: 20),

                  // ── About ──
                  _sectionTitle('About'.tr(ref), isDark),
                  const SizedBox(height: 12),
                  _infoTile('Version'.tr(ref), '1.0.0', isDark),
                  _infoTile('App'.tr(ref), 'EduSHAMIIT Parent Portal', isDark),
                  const SizedBox(height: 20),

                  // ── Logout ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authProvider.notifier).signOut(),
                      icon: const Icon(Icons.logout, color: ParentColors.error),
                      label: Text(
                        'Logout'.tr(ref),
                        style: const TextStyle(
                            color: ParentColors.error,
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ParentColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? ParentColors.darkText : ParentColors.text,
      ),
    );
  }

  Widget _toggleTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    bool isDark,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ParentColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ParentColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
      String title, IconData icon, bool isDark, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ParentColors.darkSurface : ParentColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? ParentColors.darkBorder : ParentColors.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color:
                    isDestructive ? ParentColors.error : ParentColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDestructive
                      ? ParentColors.error
                      : (isDark ? ParentColors.darkText : ParentColors.text),
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? ParentColors.darkText3 : ParentColors.text3),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? ParentColors.darkText2 : ParentColors.text2,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
            'This action cannot be undone. All your data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle account deletion
            },
            style: TextButton.styleFrom(foregroundColor: ParentColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
