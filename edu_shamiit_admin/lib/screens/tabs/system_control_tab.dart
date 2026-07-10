import 'package:flutter/material.dart';

class SystemControlTab extends StatefulWidget {
  const SystemControlTab({super.key});

  @override
  State<SystemControlTab> createState() => _SystemControlTabState();
}

class _SystemControlTabState extends State<SystemControlTab> {
  double _primaryHue = 231;
  double _accentHue = 239;

  final Map<String, Map<String, bool>> _permissions = {
    'Student': {
      'Access Timetable': true,
      'Run Exams': true,
      'Financials': false,
      'IT Control': false
    },
    'Teacher': {
      'Access Timetable': true,
      'Run Exams': true,
      'Financials': false,
      'IT Control': false
    },
    'Admin': {
      'Access Timetable': true,
      'Run Exams': true,
      'Financials': true,
      'IT Control': true
    },
  };

  final List<String> _auditLogs = [
    '[08:44:12] Gate Scanner reported check-in: Aditya Sen',
    '[08:35:50] Gate Scanner reported check-in: Mr. S. K. Roy',
    '[08:30:11] ALERT: Access denied at Gate 1 for unauthorized visitor',
    '[07:15:00] Supabase realtime channels initialized',
    '[07:00:00] System boot completed: API gateways online',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Security & Core Control',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage security permissions, customize brand themes, and view low-level system audit logs.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            final leftColumn = Column(
              children: [
                // Theme Customizer
                Container(
                  padding: const EdgeInsets.all(24),
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
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dynamic Theme Customizer (HSL Hue)',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Primary Hue: ${_primaryHue.toInt()}°',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                Slider(
                                  value: _primaryHue,
                                  min: 0,
                                  max: 360,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (val) {
                                    setState(() {
                                      _primaryHue = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Accent Hue: ${_accentHue.toInt()}°',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                Slider(
                                  value: _accentHue,
                                  min: 0,
                                  max: 360,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setState(() {
                                      _accentHue = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Permission Matrix
                Container(
                  padding: const EdgeInsets.all(24),
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
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Role Permission Matrix',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FixedColumnWidth(100),
                            1: FixedColumnWidth(120),
                            2: FixedColumnWidth(100),
                            3: FixedColumnWidth(100),
                            4: FixedColumnWidth(100),
                          },
                          children: [
                            // Headers
                            TableRow(
                              children: [
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Role',
                                        style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12))),
                                ..._permissions['Student']!.keys.map(
                                      (k) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(k,
                                            style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11)),
                                      ),
                                    ),
                              ],
                            ),
                            // Rows
                            ..._permissions.entries.map(
                              (entry) {
                                final role = entry.key;
                                final perms = entry.value;
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(role,
                                          style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13)),
                                    ),
                                    ...perms.entries.map(
                                      (perm) {
                                        final name = perm.key;
                                        final val = perm.value;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Checkbox(
                                              value: val,
                                              activeColor: const Color(0xFF4F46E5),
                                              onChanged: (bool? newVal) {
                                                setState(() {
                                                  _permissions[role]![name] = newVal ?? false;
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final rightColumn = Container(
              height: 480,
              padding: const EdgeInsets.all(24),
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
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Audit Trail Logs',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _auditLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              _auditLogs[index],
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: leftColumn),
                  const SizedBox(width: 24),
                  Expanded(child: rightColumn),
                ],
              );
            } else {
              return Column(
                children: [
                  leftColumn,
                  const SizedBox(height: 24),
                  rightColumn,
                ],
              );
            }
          }),
        ],
      ),
    );
  }
}
