import 'package:flutter/material.dart';
import 'quick_access_widgets.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  bool _sendReminders = true;
  bool _syncBiometrics = true;

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Automations Engine',
      children: [
        QuickAccessCard(
          title: 'Active Triggers & Cron',
          description: 'Manage automated systems running daily inside the Noida Cluster.',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Send Fee Reminder Messages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Auto SMS/Email notifications on 1st of every month.', style: TextStyle(fontSize: 11)),
                value: _sendReminders,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _sendReminders = val),
              ),
              SwitchListTile(
                title: const Text('Automated Biometric Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sync devices at Noida Sector 62 daily at 9:00 AM.', style: TextStyle(fontSize: 11)),
                value: _syncBiometrics,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _syncBiometrics = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
