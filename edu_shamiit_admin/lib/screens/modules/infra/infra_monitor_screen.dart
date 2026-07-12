import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminInfraMonitorScreen extends StatelessWidget {
  const AdminInfraMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Infrastructure & Telemetry Monitor',
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
            // CPU Line Chart
            Container(
              height: 220,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Noida Gateway CPU Load (9:00 - 10:00 AM)',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const Text(
                        'Spike: 87%',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 22),
                              FlSpot(1, 28),
                              FlSpot(2, 34),
                              FlSpot(3, 87), // spike
                              FlSpot(4, 45),
                              FlSpot(5, 30),
                              FlSpot(6, 25),
                            ],
                            isCurved: true,
                            color: const Color(0xFF4F46E5),
                            barWidth: 4,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Services Health List
            Text(
              'Microservices Uptime Telemetry',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),

            _buildServiceItem(context, 'Noida Gateway API', '99.9% Uptime', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'Delhi Database Cluster', '100% Uptime', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'Central Auth & Identity', '99.9% Uptime', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'Biometric Sync Broker', '94.2% Uptime', 'Degraded Load', const Color(0xFFF59E0B)),
            _buildServiceItem(context, 'LiveKit Media Gateway', '99.8% Uptime', 'Healthy', const Color(0xFF10B981)),

            const SizedBox(height: 24),

            // Network Ping Telemetry Feed
            Text(
              'Network Ping Telemetry Feed',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            _buildServiceItem(context, 'Noida Primary DB Node', '12ms Ping', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'Delhi Cluster Replica', '18ms Ping', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'White Label DNS Router', '45ms Ping', 'Healthy', const Color(0xFF10B981)),
            _buildServiceItem(context, 'Biometric Sync Webhook', '540ms Ping', 'Slow Response', const Color(0xFFF59E0B)),

            const SizedBox(height: 24),
            // Live Server Log
            Text(
              'Live System Logs',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[09:42:01] Noida DB Replica lag dropped to 12ms',
                    style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '[09:30:15] Noida biometric sync batch #145 completed: 1,840 records sync\'d',
                    style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '[09:12:44] WARNING: Noida CPU spiked to 87% during sync run',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '[09:00:00] Daily cron execution started for all Noida schools',
                    style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(
      BuildContext context, String name, String uptime, String status, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                uptime,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
