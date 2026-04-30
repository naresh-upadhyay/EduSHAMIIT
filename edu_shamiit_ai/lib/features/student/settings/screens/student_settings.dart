import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/settings_provider.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class StudentSettings extends ConsumerStatefulWidget {
  const StudentSettings({super.key});

  @override
  ConsumerState<StudentSettings> createState() => _StudentSettingsState();
}

class _StudentSettingsState extends ConsumerState<StudentSettings> {
  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => safeGoBack(context, '/student/dashboard'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Settings'.tr(ref),
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: settingsState.isLoading && settings == null
                ? const Center(child: CircularProgressIndicator())
                : settingsState.error != null && settings == null
                    ? Center(child: Text('Error: ${settingsState.error}'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Notifications Section
                          _buildSectionTitle('Notifications'.tr(ref)),
                          _buildSettingsCard([
                            _buildToggleRow(
                              icon: '🔔',
                              iconBg: StudentColors.primaryLight,
                              title: 'Push Notifications'.tr(ref),
                              subtitle: 'Homework, Results, Fees',
                              value: settings?.pushNotifications ?? true,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('pushNotifications', v),
                            ),
                            _buildToggleRow(
                              icon: '📱',
                              iconBg: StudentColors.warningBg,
                              title: 'SMS Alerts'.tr(ref),
                              subtitle: 'For critical updates only',
                              value: settings?.smsAlerts ?? true,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('smsAlerts', v),
                            ),
                            _buildToggleRow(
                              icon: '📧',
                              iconBg: StudentColors.errorBg,
                              title: 'Email Reports'.tr(ref),
                              subtitle: 'Weekly progress summary',
                              value: settings?.emailReports ?? false,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('emailReports', v),
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // AI & Privacy Section
                          _buildSectionTitle('AI & Privacy'.tr(ref)),
                          _buildSettingsCard([
                            _buildToggleRow(
                              icon: '🤖',
                              iconBg: StudentColors.primaryLight,
                              title: 'AI Personalization'.tr(ref),
                              subtitle: 'AI learns your study style',
                              value: settings?.aiPersonalization ?? true,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('aiPersonalization', v),
                            ),
                            _buildToggleRow(
                              icon: '🔐',
                              iconBg: StudentColors.successBg,
                              title: 'Biometric Login'.tr(ref),
                              subtitle: 'Face ID / Fingerprint',
                              value: settings?.biometricLogin ?? true,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('biometricLogin', v),
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // Appearance Section
                          _buildSectionTitle('Appearance'.tr(ref)),
                          _buildSettingsCard([
                            _buildToggleRow(
                              icon: '🌙',
                              iconBg: const Color(0xFF1E293B),
                              title: 'Dark Mode'.tr(ref),
                              subtitle: '',
                              value: settings?.darkMode ?? false,
                              onChanged: (v) => ref
                                  .read(settingsProvider.notifier)
                                  .updateSetting('darkMode', v),
                            ),
                            _buildNavigationRow(
                              icon: '🌐',
                              iconBg: isDark ? StudentColors.primary.withValues(alpha: 0.2) : StudentColors.infoBg,
                              title: 'Language'.tr(ref),
                              subtitle: settings?.language ?? 'English',
                              onTap: () => _showLanguageDialog(context),
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // Account Section
                          _buildSectionTitle('Account'.tr(ref)),
                          _buildSettingsCard([
                            _buildNavigationRow(
                              icon: '🔑',
                              iconBg: StudentColors.warningBg,
                              title: 'Change Password'.tr(ref),
                              subtitle: '',
                              onTap: () => _showChangePasswordDialog(context),
                            ),
                            _buildNavigationRow(
                              icon: '🚪',
                              iconBg: StudentColors.errorBg,
                              title: 'Logout'.tr(ref),
                              subtitle: '',
                              titleColor: StudentColors.error,
                              onTap: () => _showLogoutDialog(context),
                            ),
                          ]),

                          const SizedBox(height: 24),

                          // Version info
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'EduSHAMIIT v3.2.1',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: StudentColors.text3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '© ${DateTime.now().year} Shami innovation and technologies LLP',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: StudentColors.text3,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text2,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildToggleRow({
    required String icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? StudentColors.darkText : const Color(0xFF1E293B),
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? StudentColors.darkText3 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeTrackColor: StudentColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, color: isDark ? StudentColors.darkBorder : Colors.grey.withValues(alpha: 0.1)),
        ),
      ],
    );
  }

  Widget _buildNavigationRow({
    required String icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? (isDark ? StudentColors.darkText : const Color(0xFF1E293B)),
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? StudentColors.darkText3 : const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: isDark ? StudentColors.darkBorder : Colors.grey.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final settings = ref.read(settingsProvider).settings;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Select Language'.tr(ref), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(dialogCtx, 'English', settings?.language == 'English'),
              _buildLanguageOption(dialogCtx, 'Hindi', settings?.language == 'Hindi'),
              _buildLanguageOption(dialogCtx, 'Spanish', settings?.language == 'Spanish'),
              _buildLanguageOption(dialogCtx, 'French', settings?.language == 'French'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel'.tr(ref)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String language, bool isSelected) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? StudentColors.primary : (Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text3),
      ),
      title: Text(language, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
      onTap: () {
        // Capture messenger before popping
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        ref.read(settingsProvider.notifier).updateSetting('language', language);
        
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${'Language changed to'.tr(ref)} $language'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => ChangePasswordDialog(
        onUpdate: (current, newPw) async {
          final success = await ref.read(settingsProvider.notifier).changePassword(current, newPw);
          return success;
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text('Logout?'.tr(ref), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Text('Are you sure you want to logout from EduSHAMIIT?'.tr(ref), style: TextStyle(color: isDark ? StudentColors.darkText2 : StudentColors.text2)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel'.tr(ref)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: StudentColors.error),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                // Call both logout from backend and clear local session
                await ref.read(settingsProvider.notifier).logout();
                ref.read(authProvider.notifier).signOut();
              },
              child: Text('Logout'.tr(ref), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class ChangePasswordDialog extends ConsumerStatefulWidget {
  final Future<bool> Function(String current, String newPw) onUpdate;

  const ChangePasswordDialog({super.key, required this.onUpdate});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isCurrentObscured = true;
  bool _isNewObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;

  // Real-time validation states
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _newController.addListener(_validateNewPassword);
    _confirmController.addListener(_validateConfirmPassword);
  }

  void _validateNewPassword() {
    final val = _newController.text;
    setState(() {
      _hasMinLength = val.length >= 8;
      _hasNumber = val.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
    _validateConfirmPassword();
  }

  void _validateConfirmPassword() {
    setState(() {
      _matches = _confirmController.text.isNotEmpty && 
                 _confirmController.text == _newController.text;
    });
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 24,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Update Password'.tr(ref),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ensure your account stays secure'.tr(ref),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _currentController,
                        label: 'Current Password'.tr(ref),
                        hint: 'Enter your current password'.tr(ref),
                        obscured: _isCurrentObscured,
                        onToggle: () => setState(() => _isCurrentObscured = !_isCurrentObscured),
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _newController,
                        label: 'New Password'.tr(ref),
                        hint: 'Enter new secure password'.tr(ref),
                        obscured: _isNewObscured,
                        onToggle: () => setState(() => _isNewObscured = !_isNewObscured),
                      ),
                      const SizedBox(height: 12),
                      // Validation indicators
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildValidationHint('8+ chars'.tr(ref), _hasMinLength),
                          _buildValidationHint('Number'.tr(ref), _hasNumber),
                          _buildValidationHint('Symbol'.tr(ref), _hasSpecialChar),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _confirmController,
                        label: 'Confirm New Password'.tr(ref),
                        hint: 'Re-type new password'.tr(ref),
                        obscured: _isConfirmObscured,
                        onToggle: () => setState(() => _isConfirmObscured = !_isConfirmObscured),
                      ),
                      const SizedBox(height: 12),
                      _buildValidationHint('Passwords match'.tr(ref), _matches),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel'.tr(ref)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleUpdate,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('Update'.tr(ref)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationHint(String text, bool isValid) {
    final color = isValid ? Colors.green : (Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isValid ? Icons.check_circle : Icons.circle_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscured,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: IconButton(
              icon: Icon(obscured ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    // Custom validation logic
    if (_currentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter current password'.tr(ref))),
      );
      return;
    }
    if (!_hasMinLength || !_hasNumber || !_hasSpecialChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please meet all password requirements'.tr(ref))),
      );
      return;
    }
    if (!_matches) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Passwords do not match'.tr(ref))),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await widget.onUpdate(_currentController.text, _newController.text);
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Password updated successfully!'.tr(ref)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Backend returns 400 now, so this will show the error snackbar instead of logging out
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Incorrect current password. Please try again.'.tr(ref)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
