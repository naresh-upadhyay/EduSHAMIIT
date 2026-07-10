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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biometric Gate Scanner Console',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor real-time student check-ins, RFID cards logs, and gate security exceptions.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),

          // Simulator Panel
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
                  'Biometric & RFID Hardware Simulator',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final buttons = [
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan('Nidhi Patel',
                          'Student (10B)', 'Main Gate 1', 'RFID Card', true),
                      icon: const Icon(Icons.credit_card_rounded, size: 16),
                      label: const Text('Student Tap (RFID)', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (!isWide) const SizedBox(height: 10) else const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan('Mr. Aniket Das',
                          'Teacher', 'Staff Entry', 'Fingerprint', true),
                      icon: const Icon(Icons.fingerprint_rounded, size: 16),
                      label: const Text('Staff Scanner', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    if (!isWide) const SizedBox(height: 10) else const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _simulateScan(
                          'Intruder Check',
                          'Blacklisted Profile',
                          'Main Gate 1',
                          'Camera Face Scan',
                          false),
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Access Exception', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ];

                  if (isWide) {
                    return Row(children: buttons);
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: buttons,
                    );
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Log List
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
                  'Active Scan Logs (Live Connection)',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
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
                        color: isDark ? const Color(0xFF0F1222) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApproved
                              ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                              : Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  isApproved
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.cancel_outlined,
                                  color: isApproved
                                      ? const Color(0xFF10B981)
                                      : Colors.red,
                                  size: 22,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log['name'],
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          fontFamily: 'Outfit',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${log['role']}  •  ${log['gate']}  •  Via ${log['method']}",
                                        style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 11,
                                          fontFamily: 'Outfit',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            log['time'],
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              fontFamily: 'Outfit',
                            ),
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
