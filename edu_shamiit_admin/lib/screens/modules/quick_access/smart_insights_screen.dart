import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SmartInsightsScreen extends ConsumerStatefulWidget {
  const SmartInsightsScreen({super.key});

  @override
  ConsumerState<SmartInsightsScreen> createState() => _SmartInsightsScreenState();
}

class _SmartInsightsScreenState extends ConsumerState<SmartInsightsScreen> {
  List<dynamic> _schools = [];
  String _selectedSchoolId = "All Institutions";
  bool _isLoading = true;
  bool _isSendingChat = false;
  bool _chatHistoryLoading = true;

  List<dynamic> _insights = [];
  List<dynamic> _recommendations = [];
  List<dynamic> _predictions = [];
  Map<String, dynamic> _metrics = {};
  List<dynamic> _chatHistory = [];

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _fetchData();
    _fetchChatHistory();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    try {
      final res = await ApiService().get('/admin/schools');
      if (mounted && res['data'] != null) {
        setState(() {
          _schools = res['data']['schools'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching schools: $e");
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final queryParam = _selectedSchoolId == "All Institutions" ? "" : "?school_id=$_selectedSchoolId";
      final res = await ApiService().get('/admin/insights$queryParam', useCache: false);
      if (mounted && res['success'] == true && res['data'] != null) {
        setState(() {
          _insights = res['data']['insights'] ?? [];
          _recommendations = res['data']['recommendations'] ?? [];
          _predictions = res['data']['predictions'] ?? [];
          _metrics = res['data']['metrics'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching insights: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchChatHistory() async {
    setState(() {
      _chatHistoryLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/insights/chat/history', useCache: false);
      if (mounted && res['success'] == true && res['data'] != null) {
        setState(() {
          _chatHistory = res['data'] ?? [];
          _chatHistoryLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
      if (mounted) {
        setState(() {
          _chatHistoryLoading = false;
        });
      }
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSendingChat = true;
      _chatHistory.add({
        "message": text,
        "response": "...",
        "created_at": DateTime.now().toIso8601String()
      });
      _chatController.clear();
    });
    _scrollToBottom();

    try {
      final res = await ApiService().post('/admin/insights/chat', {
        "message": text
      });
      if (mounted && res['success'] == true) {
        _fetchChatHistory();
      }
    } catch (e) {
      debugPrint("Error sending chat: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSendingChat = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF090B15) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Text(
              "AI Smart Insights",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: const Text(
                "Beta",
                style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          _buildInstitutionFilter(isDark),
          const SizedBox(width: 12),
          _buildDateRangeButton(isDark),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              _fetchData();
              _fetchChatHistory();
            },
            icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
            label: const Text("Refresh Insights", style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1200;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      Text(
                        "Intelligent insights and recommendations to help you make data-driven decisions.",
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Top KPI Row
                      _buildKPIMetricsRow(isDark, isWide),
                      const SizedBox(height: 18),

                      // Responsive grid layout
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Key Insights & Recommendations)
                            Expanded(
                              flex: 35,
                              child: Column(
                                children: [
                                  _buildKeyInsightsCard(isDark),
                                  const SizedBox(height: 18),
                                  _buildRecommendationsCard(isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Middle Column (Analytics Overview & At a Glance)
                            Expanded(
                              flex: 50,
                              child: Column(
                                children: [
                                  _buildAnalyticsOverviewCard(isDark),
                                  const SizedBox(height: 18),
                                  _buildAtAGlanceCard(isDark),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Right Column (AI Assistant & Predictions)
                            Expanded(
                              flex: 35,
                              child: Column(
                                children: [
                                  _buildAIAssistantCard(isDark),
                                  const SizedBox(height: 18),
                                  _buildPredictionsCard(isDark),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildKeyInsightsCard(isDark),
                            const SizedBox(height: 18),
                            _buildAnalyticsOverviewCard(isDark),
                            const SizedBox(height: 18),
                            _buildAIAssistantCard(isDark),
                            const SizedBox(height: 18),
                            _buildRecommendationsCard(isDark),
                            const SizedBox(height: 18),
                            _buildPredictionsCard(isDark),
                            const SizedBox(height: 18),
                            _buildAtAGlanceCard(isDark),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInstitutionFilter(bool isDark) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSchoolId,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedSchoolId = val;
              });
              _fetchData();
            }
          },
          items: [
            const DropdownMenuItem(
              value: "All Institutions",
              child: Text("All Institutions"),
            ),
            ..._schools.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'].toString(),
                child: Text(s['name'].toString()),
              );
            })
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton(bool isDark) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.grey : Colors.black54),
            const SizedBox(width: 8),
            Text(
              "May 18 – May 24, 2025",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIMetricsRow(bool isDark, bool isWide) {
    final list = [
      _buildKPICard(
        title: "Overall Health Score",
        value: "${_metrics['overall_health_score'] ?? 92}/100",
        subtitle: _metrics['overall_health_status'] ?? "Excellent",
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFF10B981),
        chart: SizedBox(
          width: 50,
          height: 20,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: const [FlSpot(0, 70), FlSpot(1, 75), FlSpot(2, 72), FlSpot(3, 85), FlSpot(4, 92)],
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                )
              ],
            ),
          ),
        ),
      ),
      _buildKPICard(
        title: "Active Users (${_selectedSchoolId == 'All Institutions' ? 'All' : 'School'})",
        value: NumberFormat('#,###').format(_metrics['active_users'] ?? 12478),
        subtitle: "${_metrics['active_users_change'] ?? '↑ 8.6%'} from last 7 days",
        icon: Icons.people_outline_rounded,
        iconColor: const Color(0xFF6366F1),
      ),
      _buildKPICard(
        title: "System Alerts",
        value: "${_metrics['system_alerts'] ?? 7}",
        subtitle: "${_metrics['critical_alerts'] ?? 3} Critical • ${_metrics['warning_alerts'] ?? 4} Warning",
        icon: Icons.shield_outlined,
        iconColor: const Color(0xFFEF4444),
      ),
      _buildKPICard(
        title: "Predicted Issues",
        value: "${_metrics['predicted_issues'] ?? 5}",
        subtitle: "View predictions →",
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
      _buildKPICard(
        title: "Automation Savings",
        value: "${_metrics['automation_savings'] ?? 32.5} hrs",
        subtitle: "This week",
        icon: Icons.smart_toy_outlined,
        iconColor: const Color(0xFF06B6D4),
      ),
    ];

    if (isWide) {
      return Row(
        children: list.map((card) => Expanded(child: card)).toList(),
      );
    } else {
      return SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: list.map((card) => SizedBox(width: 220, child: card)).toList(),
        ),
      );
    }
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? chart,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF131522) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: iconColor, size: 14),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                if (chart != null) chart,
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: subtitle.contains("Critical")
                    ? const Color(0xFFEF4444)
                    : (subtitle.contains("Excellent") || subtitle.contains("↑") ? const Color(0xFF10B981) : Colors.grey),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyInsightsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Key Insights", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Icon(Icons.lightbulb_outline_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          if (_insights.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text("No key insights for this context.", style: TextStyle(color: Colors.grey, fontSize: 12))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final item = _insights[idx];
                final type = item['type'].toString().toLowerCase();
                Color alertColor = const Color(0xFF6366F1);
                String tag = "Info";
                if (type == "positive") {
                  alertColor = const Color(0xFF10B981);
                  tag = "Positive";
                } else if (type == "critical") {
                  alertColor = const Color(0xFFEF4444);
                  tag = "Critical";
                } else if (type == "warning") {
                  alertColor = const Color(0xFFF59E0B);
                  tag = "Warning";
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: alertColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['title'] ?? '',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: alertColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(color: alertColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['description'] ?? '',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI Recommendations", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_recommendations.isEmpty)
            const Center(child: Text("No recommendations available.", style: TextStyle(color: Colors.grey, fontSize: 12)))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: _recommendations.length,
              itemBuilder: (context, idx) {
                final rec = _recommendations[idx];
                IconData categoryIcon = Icons.settings_rounded;
                if (rec['category'] == 'Fee') categoryIcon = Icons.payment_rounded;
                if (rec['category'] == 'Attendance') categoryIcon = Icons.people_outline_rounded;
                if (rec['category'] == 'Content') categoryIcon = Icons.menu_book_rounded;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(categoryIcon, size: 14, color: const Color(0xFF818CF8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rec['title'] ?? '',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          rec['description'] ?? '',
                          style: const TextStyle(fontSize: 9.5, color: Colors.grey, height: 1.25),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("View Recommendation", style: TextStyle(fontSize: 10, color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Analytics Overview", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: "Daily",
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (_) {},
                    items: const [
                      DropdownMenuItem(value: "Daily", child: Text("Daily")),
                      DropdownMenuItem(value: "Weekly", child: Text("Weekly")),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text("User Activity Trend", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [FlSpot(0, 5), FlSpot(1, 9.8), FlSpot(2, 8), FlSpot(3, 11), FlSpot(4, 9.5), FlSpot(5, 12)],
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [FlSpot(0, 3), FlSpot(1, 5.5), FlSpot(2, 4.2), FlSpot(3, 7.8), FlSpot(4, 6.2), FlSpot(5, 8.5)],
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text("Top Modules by Usage", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 40,
                child: SizedBox(
                  height: 100,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(value: 28.5, color: const Color(0xFF6366F1), radius: 12, showTitle: false),
                        PieChartSectionData(value: 23.1, color: const Color(0xFF10B981), radius: 12, showTitle: false),
                        PieChartSectionData(value: 18.7, color: const Color(0xFFF59E0B), radius: 12, showTitle: false),
                        PieChartSectionData(value: 16.4, color: const Color(0xFF06B6D4), radius: 12, showTitle: false),
                        PieChartSectionData(value: 13.3, color: const Color(0xFFEF4444), radius: 12, showTitle: false),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(label: "Attendance (28.5%)", color: Color(0xFF6366F1)),
                    SizedBox(height: 4),
                    _LegendRow(label: "Examinations (23.1%)", color: Color(0xFF10B981)),
                    SizedBox(height: 4),
                    _LegendRow(label: "Fees (18.7%)", color: Color(0xFFF59E0B)),
                    SizedBox(height: 4),
                    _LegendRow(label: "Academics (16.4%)", color: Color(0xFF06B6D4)),
                    SizedBox(height: 4),
                    _LegendRow(label: "Others (13.3%)", color: Color(0xFFEF4444)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: Color(0xFF818CF8), size: 16),
                  SizedBox(width: 8),
                  Text("AI Assistant", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text("View history →", style: TextStyle(fontSize: 10, color: Color(0xFF818CF8))),
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: _chatHistoryLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: _chatHistory.isEmpty ? 1 : _chatHistory.length,
                    itemBuilder: (context, idx) {
                      if (_chatHistory.isEmpty) {
                        return const Center(
                          child: Text(
                            "Hello Super Admin! I'm your AI assistant. Ask me questions about system performance, fee collection, or diagnostics.",
                            style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.3),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final item = _chatHistory[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6, left: 24),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['message'] ?? '',
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12, right: 24),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['response'] ?? '',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  onSubmitted: (_) => _sendChatMessage(),
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Ask me anything...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _isSendingChat ? null : _sendChatMessage,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSendingChat
                      ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Predictions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Icon(Icons.query_stats_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          if (_predictions.isEmpty)
            const Center(child: Text("No active predictions.", style: TextStyle(color: Colors.grey, fontSize: 12)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _predictions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final pred = _predictions[idx];
                final prob = pred['probability'] as int? ?? 50;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.online_prediction_rounded,
                        color: prob >= 75 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pred['title'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              pred['description'] ?? '',
                              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (prob >= 75 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "$prob% prob",
                          style: TextStyle(
                            color: prob >= 75 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAtAGlanceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131522) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("At a Glance (This Week)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGlanceMetric(
                label: "New Admissions",
                value: "${_metrics['new_admissions'] ?? 342}",
                change: _metrics['new_admissions_change'] ?? "+12.5%",
                isPositive: true,
              ),
              _buildGlanceMetric(
                label: "Fees Collected",
                value: "${_metrics['fees_collected'] ?? '₹ 48.7 L'}",
                change: _metrics['fees_collected_change'] ?? "-5.3%",
                isPositive: false,
              ),
              _buildGlanceMetric(
                label: "Attendance Avg.",
                value: "${_metrics['attendance_avg'] ?? 78}%",
                change: _metrics['attendance_avg_change'] ?? "-4.0%",
                isPositive: false,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildGlanceMetric(
                label: "Support Tickets",
                value: "${_metrics['support_tickets'] ?? 128}",
                change: _metrics['support_tickets_change'] ?? "+8.1%",
                isPositive: true,
              ),
              _buildGlanceMetric(
                label: "System Uptime",
                value: "${_metrics['system_uptime'] ?? 99.9}%",
                change: _metrics['system_uptime_change'] ?? "+0.1%",
                isPositive: true,
              ),
              _buildGlanceMetric(
                label: "Automation Exec.",
                value: "${_metrics['automation_executions'] ?? 1234}",
                change: _metrics['automation_executions_change'] ?? "+15.6%",
                isPositive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlanceMetric({
    required String label,
    required String value,
    required String change,
    required bool isPositive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.01) : Colors.grey.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
