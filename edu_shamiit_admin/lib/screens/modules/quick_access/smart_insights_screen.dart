import 'package:flutter/material.dart';
import 'quick_access_widgets.dart';

class SmartInsightsScreen extends StatelessWidget {
  const SmartInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'AI Smart Insights',
      children: [
        QuickAccessCard(
          title: 'Automated Diagnostic Feed',
          description: 'Real-time issues flagged by Shamiit AI diagnostics.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightAlert('Biometric Broker Lag', 'Noida Gateway experienced 4 pings with lag > 500ms between 9:00 - 10:00 AM.', Colors.amber),
              const SizedBox(height: 12),
              _buildInsightAlert('License Renewal Expiry', '3 schools in Gurugram Region expire within 30 days. Auto invoice drafted.', Colors.redAccent),
            ],
          ),
        ),
        QuickAccessCard(
          title: 'Automated Scaling Telemetry',
          description: 'Status of CPU-based autoscaling configurations.',
          child: Column(
            children: [
              _buildMetricItem('Autoscaling Target CPU', '75% load threshold'),
              _buildMetricItem('Current Instance Count', '3 Active Nodes'),
              _buildMetricItem('Auto-mitigation Status', 'Idle — Noida cluster healthy'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightAlert(String title, String desc, Color alertColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: alertColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: alertColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
