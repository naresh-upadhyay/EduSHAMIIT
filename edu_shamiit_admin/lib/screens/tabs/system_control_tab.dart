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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Security & Core Control',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage security permissions, customize brand themes, and view low-level system audit logs.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Permission Matrix & Hue Customizer
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Theme Customizer
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13182C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dynamic Theme Customizer (HSL Hue)',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Primary Hue: ${_primaryHue.toInt()}°',
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8))),
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
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8))),
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
                        color: const Color(0xFF13182C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Role Permission Matrix',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                              4: FlexColumnWidth(1),
                            },
                            children: [
                              // Headers
                              TableRow(
                                children: [
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Role',
                                          style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.bold))),
                                  ..._permissions['Student']!.keys.map(
                                        (k) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          child: Text(k,
                                              style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
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
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Text(role,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      ...perms.entries.map(
                                        (perm) {
                                          final name = perm.key;
                                          final val = perm.value;
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 4),
                                            child: Checkbox(
                                              value: val,
                                              activeColor:
                                                  const Color(0xFF4F46E5),
                                              onChanged: (bool? newVal) {
                                                setState(() {
                                                  _permissions[role]![name] =
                                                      newVal ?? false;
                                                });
                                              },
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right: Live System Audit Logs
              Expanded(
                child: Container(
                  height: 480,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B15),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Audit Trail Logs',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _auditLogs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  _auditLogs[index],
                                  style: const TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
