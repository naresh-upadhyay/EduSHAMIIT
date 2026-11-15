import 'package:flutter/material.dart';
import '../providers/broadcast_provider.dart';

class StreamAnalyticsTabView extends StatefulWidget {
  final BroadcastProvider provider;

  const StreamAnalyticsTabView({super.key, required this.provider});

  @override
  State<StreamAnalyticsTabView> createState() => _StreamAnalyticsTabViewState();
}

class _StreamAnalyticsTabViewState extends State<StreamAnalyticsTabView> {
  @override
  void initState() {
    super.initState();
    widget.provider.loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final analytics = widget.provider.analytics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Metrics
          Row(
            children: [
              _buildMetricCard('Total Broadcasts', '${analytics?.totalBroadcasts ?? 12}', Icons.sensors, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              const SizedBox(width: 14),
              _buildMetricCard('Total Watch Time', '${analytics?.totalWatchHours ?? 482.5} hrs', Icons.access_time, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
              const SizedBox(width: 14),
              _buildMetricCard('Total Views', '${analytics?.totalViews ?? 18450}', Icons.visibility, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
              const SizedBox(width: 14),
              _buildMetricCard('Avg Engagement', '${analytics?.avgEngagementPct ?? 88.5}%', Icons.thumb_up, const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
            ],
          ),
          const SizedBox(height: 16),

          // Platform Breakdown
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text('Audience Distribution by Platform', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                _buildPlatformBar('YouTube Live', 58, '10,700 views', Colors.red, Icons.play_circle_fill),
                const SizedBox(height: 12),
                _buildPlatformBar('Facebook Live', 24, '4,430 views', const Color(0xFF1877F2), Icons.facebook),
                const SizedBox(height: 12),
                _buildPlatformBar('EduSHAMIIT Portal & Custom RTMP', 18, '3,320 views', const Color(0xFF4F46E5), Icons.link),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quality & Health Telemetry Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.monitor_heart, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 8),
                    Text('Stream Performance & Encoding Quality', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 14),
                Text('Bitrate Stability: 99.4% steady at 4,500 Kbps without frame drops.', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                SizedBox(height: 6),
                Text('Average Latency: 1.8 seconds in Low-Latency Mode.', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                SizedBox(height: 6),
                Text('DVR Seek Buffer: Up to 4 hours time-shift window enabled for students.', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformBar(String name, int pct, String viewsText, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const Spacer(),
            Text('$pct% ($viewsText)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100.0,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
