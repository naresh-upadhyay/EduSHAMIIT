import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/teacher_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/settings_provider.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final settings = settingsState.settings;
    final authState = ref.watch(authProvider);
    final isTeacher = authState.role == UserRole.teacher;

    // Theme values based on role
    final primaryColor = isTeacher ? TeacherColors.primary : StudentColors.primary;
    final surfaceColor = isTeacher ? TeacherColors.surface : StudentColors.surface;
    final backgroundColor = isTeacher ? TeacherColors.background : const Color(0xFFF5F6FF);
    final textColor = isTeacher ? TeacherColors.text : StudentColors.text;
    final text2Color = isTeacher ? TeacherColors.text2 : StudentColors.text2;
    final text3Color = isTeacher ? TeacherColors.text3 : StudentColors.text3;
    final primaryGradient = isTeacher ? AppGradients.teacherPrimary : AppGradients.studentPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => safeGoBack(context, dashboardFallback(context)),
        ),
        title: Text(
          'Settings'.tr(ref),
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
      body: settingsState.isLoading && settings == null
          ? const Center(child: CircularProgressIndicator())
          : settingsState.error != null && settings == null
              ? Center(child: Text('Error: ${settingsState.error}'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile Section
                    _buildProfileCard(primaryGradient, primaryColor),
                    const SizedBox(height: 20),

                    // Preferences Section
                    _buildSectionTitle('Preferences'.tr(ref), text2Color),
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Push Notifications'.tr(ref),
                      subtitle: 'Homework, Results, Fees'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Switch(
                        value: settings?.pushNotifications ?? true,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .updateSetting('pushNotifications', value),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.sms_outlined,
                      title: 'SMS Alerts'.tr(ref),
                      subtitle: 'For critical updates only'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Switch(
                        value: settings?.smsAlerts ?? true,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .updateSetting('smsAlerts', value),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.mail_outline,
                      title: 'Email Reports'.tr(ref),
                      subtitle: 'Weekly progress summary'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Switch(
                        value: settings?.emailReports ?? false,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .updateSetting('emailReports', value),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark Mode'.tr(ref),
                      subtitle: 'Switch to dark theme'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Switch(
                        value: settings?.darkMode ?? false,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .updateSetting('darkMode', value),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.fingerprint_outlined,
                      title: 'Biometric Login'.tr(ref),
                      subtitle: 'Face ID / Fingerprint'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Switch(
                        value: settings?.biometricLogin ?? true,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .updateSetting('biometricLogin', value),
                        activeThumbColor: primaryColor,
                        activeTrackColor: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    _buildSettingsTile(
                      icon: Icons.language_outlined,
                      title: 'Language'.tr(ref),
                      subtitle: settings?.language ?? 'English',
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Icon(Icons.chevron_right, color: text3Color),
                      onTap: () => _showLanguageDialog(),
                    ),
                    const SizedBox(height: 20),

                    // Account Section
                    _buildSectionTitle('Account'.tr(ref), text2Color),
                    _buildSettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password'.tr(ref),
                      subtitle: 'Update your password'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Icon(Icons.chevron_right, color: text3Color),
                      onTap: () => _showChangePasswordDialog(),
                    ),
                    _buildSettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy'.tr(ref),
                      subtitle: 'Read our privacy policy'.tr(ref),
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Icon(Icons.chevron_right, color: text3Color),
                      onTap: () {},
                    ),
                    _buildSettingsTile(
                      icon: Icons.info_outline,
                      title: 'About EduSHAMIIT'.tr(ref),
                      subtitle: 'Version 3.2.1',
                      primaryColor: primaryColor,
                      textColor: textColor,
                      text3Color: text3Color,
                      trailing: Icon(Icons.chevron_right, color: text3Color),
                      onTap: () {},
                    ),
                    const SizedBox(height: 40),

                    // Logout Button
                    ElevatedButton(
                      onPressed: () => _showLogoutDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red.withValues(alpha: 0.1)),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout),
                          const SizedBox(width: 8),
                          Text(
                            'Log Out'.tr(ref),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '© ${DateTime.now().year} Shami Innovation and Technologies LLP',
                        style: TextStyle(
                          fontSize: 12,
                          color: text3Color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileCard(LinearGradient gradient, Color primaryColor) {
    final authState = ref.watch(authProvider);
    final userData = authState.userData;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: Text(
                userData?['email']?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData?['full_name'] ?? userData?['email']?.split('@')[0] ?? 'User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  userData?['email'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Color primaryColor,
    required Color textColor,
    required Color text3Color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: text3Color,
            ),
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Language'.tr(ref)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', '🇺🇸'),
            _buildLanguageOption('Hindi', '🇮🇳'),
            _buildLanguageOption('Spanish', '🇪🇸'),
            _buildLanguageOption('French', '🇫🇷'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, String flag) {
    final settings = ref.read(settingsProvider).settings;
    final isSelected = (settings?.language ?? 'English') == language;
    final isTeacher = ref.read(authProvider).role == UserRole.teacher;
    final primaryColor = isTeacher ? TeacherColors.primary : StudentColors.primary;

    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(language),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: primaryColor)
          : null,
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

  void _showChangePasswordDialog() {
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Log Out'.tr(ref)),
          content: Text('Are you sure you want to log out of EduSHAMIIT?'.tr(ref)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel'.tr(ref)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                // Call local sign out immediately to trigger navigation
                await ref.read(authProvider.notifier).signOut();
                // Optional: call backend logout in background without awaiting if it's slow
                ref.read(settingsProvider.notifier).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Log Out'.tr(ref)),
            ),
          ],
        );
      },
    );
  }
}

// Reusable custom ChangePasswordDialog
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
