import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentSettings extends ConsumerStatefulWidget {
  const StudentSettings({super.key});

  @override
  ConsumerState<StudentSettings> createState() => _StudentSettingsState();
}

class _StudentSettingsState extends ConsumerState<StudentSettings> {
  // Toggle states
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _emailReports = false;
  bool _aiPersonalization = true;
  bool _biometricLogin = true;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notifications Section
                _buildSectionTitle('Notifications'),
                _buildSettingsCard([
                  _buildToggleRow(
                    icon: '🔔',
                    iconBg: StudentColors.primaryLight,
                    title: 'Push Notifications',
                    subtitle: 'Homework, Results, Fees',
                    value: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                  ),
                  _buildToggleRow(
                    icon: '📱',
                    iconBg: StudentColors.warningBg,
                    title: 'SMS Alerts',
                    subtitle: 'For critical updates only',
                    value: _smsAlerts,
                    onChanged: (v) => setState(() => _smsAlerts = v),
                  ),
                  _buildToggleRow(
                    icon: '📧',
                    iconBg: StudentColors.errorBg,
                    title: 'Email Reports',
                    subtitle: 'Weekly progress summary',
                    value: _emailReports,
                    onChanged: (v) => setState(() => _emailReports = v),
                  ),
                ]),

                const SizedBox(height: 16),

                // AI & Privacy Section
                _buildSectionTitle('AI & Privacy'),
                _buildSettingsCard([
                  _buildToggleRow(
                    icon: '🤖',
                    iconBg: StudentColors.primaryLight,
                    title: 'AI Personalization',
                    subtitle: 'AI learns your study style',
                    value: _aiPersonalization,
                    onChanged: (v) => setState(() => _aiPersonalization = v),
                  ),
                  _buildToggleRow(
                    icon: '🔐',
                    iconBg: StudentColors.successBg,
                    title: 'Biometric Login',
                    subtitle: 'Face ID / Fingerprint',
                    value: _biometricLogin,
                    onChanged: (v) => setState(() => _biometricLogin = v),
                  ),
                ]),

                const SizedBox(height: 16),

                // Appearance Section
                _buildSectionTitle('Appearance'),
                _buildSettingsCard([
                  _buildToggleRow(
                    icon: '🌙',
                    iconBg: const Color(0xFF1E293B),
                    title: 'Dark Mode',
                    subtitle: '',
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
                  ),
                  _buildNavigationRow(
                    icon: '🌐',
                    iconBg: StudentColors.infoBg,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () => _showLanguageDialog(),
                  ),
                ]),

                const SizedBox(height: 16),

                // Account Section
                _buildSectionTitle('Account'),
                _buildSettingsCard([
                  _buildNavigationRow(
                    icon: '🔑',
                    iconBg: StudentColors.warningBg,
                    title: 'Change Password',
                    subtitle: '',
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  _buildNavigationRow(
                    icon: '🚪',
                    iconBg: StudentColors.errorBg,
                    title: 'Logout',
                    subtitle: '',
                    titleColor: StudentColors.error,
                    onTap: () => _showLogoutDialog(),
                  ),
                ]),

                const SizedBox(height: 24),

                // Version info
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'EduVerse v3.2.1',
                        style: TextStyle(
                          fontSize: 10,
                          color: StudentColors.text3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '© 2025 EduVerse Technologies',
                        style: TextStyle(
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: StudentColors.text3,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: StudentColors.text3,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onChanged(!value),
                child: Container(
                  width: 36,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value ? StudentColors.primary : StudentColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: StudentColors.border),
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
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: StudentColors.text3,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: StudentColors.text3,
                  size: 20,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: StudentColors.border),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', true),
            _buildLanguageOption('Hindi', false),
            _buildLanguageOption('Spanish', false),
            _buildLanguageOption('French', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isSelected) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? StudentColors.primary : StudentColors.text3,
      ),
      title: Text(language),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Language changed to $language')),
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Password changed successfully!')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout from EduVerse?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentColors.error),
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}