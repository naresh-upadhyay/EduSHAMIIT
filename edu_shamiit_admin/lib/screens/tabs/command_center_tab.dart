import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class CommandCenterTab extends StatelessWidget {
  const CommandCenterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Command Center',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Realtime overview of school operations, stats, and financials.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Stat Cards Grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            shrinkWrap: true,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                context,
                title: 'Total Students',
                value: '1,248',
                subText: '+42 new admissions this term',
                icon: Icons.people_outline_rounded,
                iconColor: const Color(0xFF3B82F6),
              ),
              _buildStatCard(
                context,
                title: 'Active Teachers',
                value: '84',
                subText: '2 currently on approved leave',
                icon: Icons.school_outlined,
                iconColor: const Color(0xFF10B981),
              ),
              _buildStatCard(
                context,
                title: 'Month Fee Collection',
                value: '₹18,45,200',
                subText: '91% of targeted collection reached',
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFFF59E0B),
              ),
              _buildStatCard(
                context,
                title: 'Support Tickets',
                value: '7 Pending',
                subText: 'Average resolution time: 2.4 hrs',
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Core charts & recent logs
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Charts
              Expanded(
                flex: 2,
                child: Container(
                  height: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13182C),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fee Collection Progress (Last 6 Months)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const months = [
                                      'Jan',
                                      'Feb',
                                      'Mar',
                                      'Apr',
                                      'May',
                                      'Jun'
                                    ];
                                    if (value >= 0 && value < months.length) {
                                      return Text(
                                        months[value.toInt()],
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 12),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: const [
                                  FlSpot(0, 12),
                                  FlSpot(1, 14),
                                  FlSpot(2, 11),
                                  FlSpot(3, 15),
                                  FlSpot(4, 18),
                                  FlSpot(5, 17.5),
                                ],
                                isCurved: true,
                                color: const Color(0xFF4F46E5),
                                barWidth: 4,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFF4F46E5)
                                      .withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right: Recent Activities List
              Expanded(
                child: Container(
                  height: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13182C),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Activities Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildActivityItem('RFID: Gate Scanner',
                                'Student 10A checked in', '08:12 AM'),
                            _buildActivityItem('Finance',
                                'Fee payment processed for 11B', '08:05 AM'),
                            _buildActivityItem('Admissions',
                                'New application registered', 'Yesterday'),
                            _buildActivityItem(
                                'System Security',
                                'Permission matrix updated by Admin',
                                'Yesterday'),
                          ],
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

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subText,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13182C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
              Icon(icon, color: iconColor, size: 24),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subText,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String category, String detail, String timestamp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          Text(
            timestamp,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
