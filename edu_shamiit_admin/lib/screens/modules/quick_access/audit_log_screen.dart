import 'package:flutter/material.dart';
import 'quick_access_widgets.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Audit Logs',
      children: [
        QuickAccessCard(
          title: 'Security Trail Logs',
          description: 'Historical list of super admin configurations and toggles.',
          child: Column(
            children: [
              _buildAuditItem('[14:20:00] Rahul Kapoor updated Noida database replica delay.', '127.0.0.1'),
              _buildAuditItem('[12:00:15] Naresh Upadhyay created tenant: Gurugram Prep.', '192.168.1.1'),
              _buildAuditItem('[09:00:00] System Cron synchronized Biometric Batch #145.', 'CronDaemon'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditItem(String logText, String ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(logText, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 8),
          Text(ip, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
