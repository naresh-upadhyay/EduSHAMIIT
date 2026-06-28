import 'package:flutter/material.dart';

class GateScannerTab extends StatefulWidget {
  const GateScannerTab({super.key});

  @override
  State<GateScannerTab> createState() => _GateScannerTabState();
}

class _GateScannerTabState extends State<GateScannerTab> {
  final List<Map<String, dynamic>> _scanLogs = [
    {
      'time': '08:44:12 AM',
      'name': 'Aditya Sen',
      'role': 'Student (10A)',
      'gate': 'Main Gate 1',
      'status': 'Approved',
      'method': 'RFID Card'
    },
    {
      'time': '08:42:05 AM',
      'name': 'Nisha Goel',
      'role': 'Student (12B)',
      'gate': 'East Wing 2',
      'status': 'Approved',
      'method': 'Biometric Face ID'
    },
    {
      'time': '08:35:50 AM',
      'name': 'Mr. S. K. Roy',
      'role': 'Teacher',
      'gate': 'Staff Entry',
      'status': 'Approved',
      'method': 'Fingerprint'
    },
    {
      'time': '08:30:11 AM',
      'name': 'Unknown Person',
      'role': 'Visitor',
      'gate': 'Main Gate 1',
      'status': 'Rejected',
      'method': 'Unauthorized Access Attempt'
    },
  ];

  void _simulateScan(
      String name, String role, String gate, String method, bool success) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    setState(() {
      _scanLogs.insert(0, {
        'time': timeStr,
        'name': name,
        'role': role,
        'gate': gate,
        'status': success ? 'Approved' : 'Rejected',
        'method': method,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Simulated Scan: $name - ${success ? 'Access Approved' : 'Access Denied'}'),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biometric Gate Scanner Console',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor real-time student check-ins, RFID cards logs, and gate security exceptions.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),

          // Simulator Panel
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Biometric & RFID Hardware Simulator',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan('Nidhi Patel',
                          'Student (10B)', 'Main Gate 1', 'RFID Card', true),
                      icon: const Icon(Icons.credit_card_rounded),
                      label: const Text('Simulate Student Tap (RFID)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan('Mr. Aniket Das',
                          'Teacher', 'Staff Entry', 'Fingerprint', true),
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Simulate Staff Scanner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan(
                          'Intruder Check',
                          'Blacklisted Profile',
                          'Main Gate 1',
                          'Camera Face Scan',
                          false),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Simulate Access Exception'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Log List
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF13182C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Scan Logs (Live Connection)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scanLogs.length,
                  itemBuilder: (context, index) {
                    final log = _scanLogs[index];
                    final isApproved = log['status'] == 'Approved';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1222),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApproved
                              ? Colors.transparent
                              : Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isApproved
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.cancel_outlined,
                                color: isApproved
                                    ? const Color(0xFF10B981)
                                    : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log['name'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${log['role']}  •  ${log['gate']}  •  Via ${log['method']}",
                                    style: const TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            log['time'],
                            style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
