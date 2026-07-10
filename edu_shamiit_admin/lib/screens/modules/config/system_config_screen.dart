import 'package:flutter/material.dart';

class AdminSystemConfigScreen extends StatefulWidget {
  const AdminSystemConfigScreen({super.key});

  @override
  State<AdminSystemConfigScreen> createState() => _AdminSystemConfigScreenState();
}

class _AdminSystemConfigScreenState extends State<AdminSystemConfigScreen> {
  bool _whiteLabelEnabled = true;
  bool _academicModule = true;
  bool _financeModule = true;
  bool _hrModule = true;
  bool _transportModule = true;
  bool _biometricSync = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'System Configuration Control',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // White label branding card
            _buildSectionHeader(context, 'Branding & Customization'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Enable Tenant White Labeling',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Allow institutions to apply custom domains, logos, and custom color themes.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    value: _whiteLabelEnabled,
                    onChanged: (val) {
                      setState(() {
                        _whiteLabelEnabled = val;
                      });
                    },
                    activeThumbColor: const Color(0xFF4F46E5),
                    activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    contentPadding: EdgeInsets.zero,
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Global Portal Title',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Container(
                        width: 160,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0D19) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: isDark
                              ? null
                              : Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            'EduSHAMIIT Portal',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Modules toggles card
            _buildSectionHeader(context, 'Global Modules Registry'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                      context,
                      'Academic & Curriculum Engine',
                      'Timetables, course paths, study plans, live learning',
                      _academicModule, (val) {
                    setState(() {
                      _academicModule = val;
                    });
                  }),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleRow(
                      context,
                      'Financial & Tuition Ledger',
                      'Fee collections, recurring plans, defaulters triggers',
                      _financeModule, (val) {
                    setState(() {
                      _financeModule = val;
                    });
                  }),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleRow(
                      context,
                      'HR & Payroll Registry',
                      'Teacher salaries, bio logins, attendance tracking, leave manager',
                      _hrModule, (val) {
                    setState(() {
                      _hrModule = val;
                    });
                  }),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  _buildToggleRow(
                      context,
                      'Logistics & Transport Dispatch',
                      'Bus routing, driver mapping, live GPS tracker',
                      _transportModule, (val) {
                    setState(() {
                      _transportModule = val;
                    });
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Integrations Card
            _buildSectionHeader(context, 'Core API & Automation Control'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Biometric Sync Broker Service',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Automatically synchronize biometric terminals daily between 9:00 - 10:00 AM.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    value: _biometricSync,
                    onChanged: (val) {
                      setState(() {
                        _biometricSync = val;
                      });
                    },
                    activeThumbColor: const Color(0xFF4F46E5),
                    activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                    contentPadding: EdgeInsets.zero,
                  ),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  _buildConfigValueRow(context, 'SMTP Gateway Endpoint', 'smtp.shamiit-infra.com'),
                  const SizedBox(height: 10),
                  _buildConfigValueRow(context, 'Twilio SMS Route', 'Active — +1-888-SHAMIIT'),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildToggleRow(
      BuildContext context, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF4F46E5),
      activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildConfigValueRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
