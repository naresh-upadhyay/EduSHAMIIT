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

  late final TextEditingController _titleController;
  Color _themeColor = const Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'EduSHAMIIT Portal');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
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
            Material(
              color: theme.cardColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.04),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (_whiteLabelEnabled) ...[
                      Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Global Portal Domain Prefix',
                          hintText: 'e.g. shamiit',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintStyle: const TextStyle(fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Primary Branding Color',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [Colors.indigo, Colors.blue, Colors.green, Colors.teal, Colors.orange, Colors.purple].map((c) {
                          final isSel = _themeColor == c;
                          return GestureDetector(
                            onTap: () => setState(() => _themeColor = c),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSel ? Border.all(color: isDark ? Colors.black : Colors.white, width: 2) : null,
                                boxShadow: isSel ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Modules toggles card
            _buildSectionHeader(context, 'Global Modules Registry'),
            const SizedBox(height: 10),
            Material(
              color: theme.cardColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.04),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
            ),
            const SizedBox(height: 24),

            // Integrations Card
            _buildSectionHeader(context, 'Core API & Automation Control'),
            const SizedBox(height: 10),
            Material(
              color: theme.cardColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              shadowColor: Colors.black.withValues(alpha: 0.04),
              elevation: isDark ? 0 : 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
