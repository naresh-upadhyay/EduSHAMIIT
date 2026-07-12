import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'quick_access_widgets.dart';

class ApisScreen extends StatefulWidget {
  const ApisScreen({super.key});

  @override
  State<ApisScreen> createState() => _ApisScreenState();
}

class _ApisScreenState extends State<ApisScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  List<dynamic> _trafficOverview = [];
  List<dynamic> _categoryData = [];
  Map<String, dynamic> _gatewayStatus = {};
  List<dynamic> _recentActivity = [];
  List<dynamic> _registeredApis = [];

  // Table filtering & pagination state
  String _searchQuery = "";
  String _selectedCategory = "All Categories";
  String _selectedStatus = "All Status";
  int _currentPage = 0;
  final int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _fetchGatewayData();
  }

  Future<void> _fetchGatewayData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/schools/gateway/stats', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _metrics = data['metrics'] as Map<String, dynamic>? ?? {};
          _trafficOverview = data['traffic_overview'] as List<dynamic>? ?? [];
          _categoryData = data['category_data'] as List<dynamic>? ?? [];
          _gatewayStatus = data['gateway_status'] as Map<String, dynamic>? ?? {};
          _recentActivity = data['recent_activity'] as List<dynamic>? ?? [];
          _registeredApis = data['registered_apis'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load API Gateway data: $e')),
      );
    }
  }

  String _formatNumber(dynamic val) {
    if (val == null) return "0";
    final numVal = double.tryParse(val.toString()) ?? 0.0;
    if (numVal >= 1000000) {
      return "${(numVal / 1000000.0).toStringAsFixed(2)}M";
    } else if (numVal >= 1000) {
      return "${(numVal / 1000.0).toStringAsFixed(1)}K";
    }
    return numVal.toInt().toString();
  }

  List<FlSpot> _buildSpots(String key) {
    List<FlSpot> spots = [];
    for (int i = 0; i < _trafficOverview.length; i++) {
      final y = double.tryParse(_trafficOverview[i][key].toString()) ?? 0.0;
      spots.add(FlSpot(i.toDouble(), y));
    }
    return spots;
  }

  List<PieChartSectionData> _buildPieSections() {
    final Map<String, Color> catColors = {
      'Authentication': const Color(0xFF8B5CF6),
      'Student': const Color(0xFF3B82F6),
      'Academic': const Color(0xFF10B981),
      'Finance': const Color(0xFFF59E0B),
      'Communication': const Color(0xFFEC4899),
      'Others': const Color(0xFF6B7280),
    };

    return _categoryData.map((cd) {
      final cat = cd['category'].toString();
      final pct = double.tryParse(cd['percentage'].toString()) ?? 0.0;
      final color = catColors[cat] ?? const Color(0xFF6B7280);
      return PieChartSectionData(
        color: color,
        value: pct > 0 ? pct : 0.1,
        title: '',
        radius: 16,
      );
    }).toList();
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required ThemeData theme,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 16),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'API Gateway',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    // Filter Registered APIs
    final filteredApis = _registeredApis.where((api) {
      final name = api['api_name']?.toString().toLowerCase() ?? '';
      final path = api['path_prefix']?.toString().toLowerCase() ?? '';
      final cat = api['category']?.toString() ?? '';
      final status = api['status']?.toString() ?? '';

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || path.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == "All Categories" || cat == _selectedCategory;
      final matchesStatus = _selectedStatus == "All Status" || status == _selectedStatus;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    // Paginate filtered APIs
    final totalRecords = filteredApis.length;
    final totalPages = (totalRecords / _pageSize).ceil();
    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize) > totalRecords ? totalRecords : (startIndex + _pageSize);
    final paginatedApis = (startIndex < totalRecords) ? filteredApis.sublist(startIndex, endIndex) : [];

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'API Gateway',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            onPressed: _fetchGatewayData,
            tooltip: 'Refresh Metrics',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showCreateApiDialog(),
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text('Create New API', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards row
            _buildKpiGrid(isDesktop, theme, isDark),
            const SizedBox(height: 24),

            // Analytics Section (Charts)
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildTrafficOverviewChart(theme, isDark)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildCategoryDoughnutChart(theme, isDark)),
                ],
              )
            else
              Column(
                children: [
                  _buildTrafficOverviewChart(theme, isDark),
                  const SizedBox(height: 24),
                  _buildCategoryDoughnutChart(theme, isDark),
                ],
              ),
            const SizedBox(height: 24),

            // Main Content Split (Table + Sidebar)
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildRegisteredApisTable(paginatedApis, totalRecords, totalPages, startIndex, endIndex, theme, isDark)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildGatewayStatusCard(theme, isDark),
                        const SizedBox(height: 20),
                        _buildQuickActionsCard(theme, isDark),
                        const SizedBox(height: 20),
                        _buildRecentActivityCard(theme, isDark),
                      ],
                    ),
                  )
                ],
              )
            else
              Column(
                children: [
                  _buildRegisteredApisTable(paginatedApis, totalRecords, totalPages, startIndex, endIndex, theme, isDark),
                  const SizedBox(height: 24),
                  _buildGatewayStatusCard(theme, isDark),
                  const SizedBox(height: 20),
                  _buildQuickActionsCard(theme, isDark),
                  const SizedBox(height: 20),
                  _buildRecentActivityCard(theme, isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUB-WIDGET BUILDERS
  // =========================================================================

  Widget _buildKpiGrid(bool isDesktop, ThemeData theme, bool isDark) {
    final cards = [
      _buildKpiCard(
        'Total APIs',
        _metrics['total_apis']?.toString() ?? '0',
        '↑ 12% this month',
        Icons.view_in_ar,
        const Color(0xFF8B5CF6),
        theme,
        isDark,
      ),
      _buildKpiCard(
        'Total Requests',
        _formatNumber(_metrics['total_requests']),
        '↑ 18.4% this month',
        Icons.layers_outlined,
        const Color(0xFF3B82F6),
        theme,
        isDark,
      ),
      _buildKpiCard(
        'Success Rate',
        "${_metrics['success_rate'] ?? '99.52'}%",
        '↑ 0.8% this month',
        Icons.shield_outlined,
        const Color(0xFF10B981),
        theme,
        isDark,
      ),
      _buildKpiCard(
        'Avg. Response Time',
        "${_metrics['avg_response_time'] ?? '186'}ms",
        '↓ 12ms this month',
        Icons.bolt,
        const Color(0xFFF59E0B),
        theme,
        isDark,
      ),
      _buildKpiCard(
        'Rate Limit Hits',
        _formatNumber(_metrics['rate_limit_hits']),
        '↓ 6% this month',
        Icons.speed,
        const Color(0xFFEF4444),
        theme,
        isDark,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: 170, child: c)).toList(),
      );
    }
  }

  Widget _buildKpiCard(String title, String value, String subtext, IconData icon, Color color, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
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
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(
              color: subtext.startsWith('↑') ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficOverviewChart(ThemeData theme, bool isDark) {
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                'API Traffic Overview',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Last 7 Days',
                  style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot('Requests', const Color(0xFF8B5CF6)),
              const SizedBox(width: 14),
              _buildLegendDot('Successful', const Color(0xFF10B981)),
              const SizedBox(width: 14),
              _buildLegendDot('Failed', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _trafficOverview.isEmpty
                ? const Center(child: Text('No traffic data available', style: TextStyle(color: Colors.grey)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _trafficOverview.length) {
                                return Text(
                                  _trafficOverview[index]['label'] ?? '',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          left: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          top: BorderSide.none,
                          right: BorderSide.none,
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _buildSpots('requests'),
                          isCurved: true,
                          color: const Color(0xFF8B5CF6),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF8B5CF6).withOpacity(0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: _buildSpots('successful'),
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF10B981).withOpacity(0.05),
                          ),
                        ),
                        LineChartBarData(
                          spots: _buildSpots('failed'),
                          isCurved: true,
                          color: const Color(0xFFEF4444),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFEF4444).withOpacity(0.03),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
      ],
    );
  }

  Widget _buildCategoryDoughnutChart(ThemeData theme, bool isDark) {
    final catColors = {
      'Authentication': const Color(0xFF8B5CF6),
      'Student': const Color(0xFF3B82F6),
      'Academic': const Color(0xFF10B981),
      'Finance': const Color(0xFFF59E0B),
      'Communication': const Color(0xFFEC4899),
      'Others': const Color(0xFF6B7280),
    };

    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Requests by API Category',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Doughnut chart with center text
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          sections: _buildPieSections(),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatNumber(_metrics['total_requests']),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const Text(
                              'Total',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Legend
                Expanded(
                  child: ListView.builder(
                    itemCount: _categoryData.length,
                    itemBuilder: (context, index) {
                      final cd = _categoryData[index];
                      final cat = cd['category'].toString();
                      final pct = cd['percentage'].toString();
                      final count = cd['count'].toString();
                      final color = catColors[cat] ?? const Color(0xFF6B7280);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                  fontSize: 10,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Text(
                              "$pct% ($count)",
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('View full analytics →', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRegisteredApisTable(
    List<dynamic> apis,
    int totalRecords,
    int totalPages,
    int startIndex,
    int endIndex,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registered APIs',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 16),

          // Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 0;
                    });
                  },
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search APIs...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildDropdownFilter(
                _selectedCategory,
                ["All Categories", "Authentication", "Student", "Academic", "Finance", "Communication", "Others"],
                (val) {
                  setState(() {
                    _selectedCategory = val!;
                    _currentPage = 0;
                  });
                },
                theme,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildDropdownFilter(
                _selectedStatus,
                ["All Status", "Active", "Inactive"],
                (val) {
                  setState(() {
                    _selectedStatus = val!;
                    _currentPage = 0;
                  });
                },
                theme,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('API Name', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Category', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Version', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Requests', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Success Rate', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Avg. Response', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Actions', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),

          // Table Rows
          if (apis.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No matching APIs found', style: TextStyle(color: Color(0xFF64748B)))),
            )
          else
            ...apis.map((api) => _buildApiTableRow(api, isDark)),

          const SizedBox(height: 16),

          // Pagination Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Showing ${startIndex + 1} to $endIndex of $totalRecords APIs",
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios, size: 12),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    disabledColor: isDark ? Colors.white24 : Colors.black26,
                  ),
                  ...List.generate(totalPages, (index) {
                    final isCurrent = index == _currentPage;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFF4F46E5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            color: isCurrent ? Colors.white : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                  IconButton(
                    onPressed: _currentPage < (totalPages - 1)
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    disabledColor: isDark ? Colors.white24 : Colors.black26,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String value, List<String> items, void Function(String?) onChanged, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: theme.cardColor,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildApiTableRow(dynamic api, bool isDark) {
    final Map<String, IconData> categoryIcons = {
      'Authentication': Icons.lock_open,
      'Student': Icons.person_outline,
      'Academic': Icons.school_outlined,
      'Finance': Icons.credit_card_outlined,
      'Communication': Icons.chat_bubble_outline,
      'Others': Icons.devices_other,
    };

    final Map<String, Color> categoryColors = {
      'Authentication': const Color(0xFF8B5CF6),
      'Student': const Color(0xFF3B82F6),
      'Academic': const Color(0xFF10B981),
      'Finance': const Color(0xFFF59E0B),
      'Communication': const Color(0xFFEC4899),
      'Others': const Color(0xFF6B7280),
    };

    final cat = api['category']?.toString() ?? 'Others';
    final icon = categoryIcons[cat] ?? Icons.devices_other;
    final color = categoryColors[cat] ?? const Color(0xFF6B7280);
    final isActive = api['status']?.toString() == 'Active';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              // API Name column
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            api['api_name']?.toString() ?? '',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Text(
                            api['path_prefix']?.toString() ?? '',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Category column
              Expanded(
                flex: 2,
                child: Text(cat, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ),
              // Version column
              Expanded(
                flex: 1,
                child: Text(api['version']?.toString() ?? 'v1.0', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ),
              // Requests column
              Expanded(
                flex: 1,
                child: Text(_formatNumber(api['requests']), style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ),
              // Success Rate column
              Expanded(
                flex: 1,
                child: Text("${api['success_rate']}%", style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ),
              // Avg. Response Time column
              Expanded(
                flex: 1,
                child: Text("${api['avg_response_time']}ms", style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ),
              // Status column
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF10B981).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? "Active" : "Inactive",
                    style: TextStyle(color: isActive ? const Color(0xFF10B981) : Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Actions column
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF64748B), size: 16),
                      onPressed: () => _showApiDetailsDialog(api),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 16),
                      onPressed: () => _showEditApiDialog(api),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
      ],
    );
  }

  Widget _buildGatewayStatusCard(ThemeData theme, bool isDark) {
    final status = _gatewayStatus['status']?.toString() ?? 'Operational';
    final uptime = _gatewayStatus['uptime']?.toString() ?? '99.99%';
    final env = _gatewayStatus['environment']?.toString() ?? 'Production';
    final region = _gatewayStatus['server_region']?.toString() ?? 'Mumbai, IN';
    final ver = _gatewayStatus['gateway_version']?.toString() ?? 'v2.4.1';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
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
                'Gateway Status',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Uptime', uptime, isDark),
          _buildStatusRow('Environment', env, isDark),
          _buildStatusRow('Server Region', region, isDark),
          _buildStatusRow('Gateway Version', ver, isDark),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'View System Health →',
                style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionItem('Create New API', Icons.add_link, () => _showCreateApiDialog(), isDark),
          _buildQuickActionItem('Generate API Key', Icons.vpn_key_outlined, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mock Action: API Key "gateway-client-sdk" generated successfully!')),
            );
          }, isDark),
          _buildQuickActionItem('Simulate Traffic / Test', Icons.speed_outlined, () => _showSimulateTrafficDialog(), isDark),
          _buildQuickActionItem('View API Documentation', Icons.description_outlined, () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Redirecting to FastAPI Swagger Docs (/docs)...')),
            );
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(String label, IconData icon, void Function() onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 16),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
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
                'Recent Activity',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('View All', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 8),
          ..._recentActivity.map((activity) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(color: Color(0xFF4F46E5), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['activity']?.toString() ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF334155),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${activity['by'] ?? ''} • ${activity['time'] ?? ''}",
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // DIALOG BUILDERS & ACTIONS (PREMIUM CUSTOM MODAL DIALOGS)
  // =========================================================================

  void _showApiDetailsDialog(dynamic api) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'API Route Details',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Details Rows
                _buildDetailRow('API Name', api['api_name']?.toString() ?? '', isDark),
                _buildDetailRow('Path Prefix', api['path_prefix']?.toString() ?? '', isDark),
                _buildDetailRow('Category', api['category']?.toString() ?? '', isDark),
                _buildDetailRow('Version', api['version']?.toString() ?? 'v1.0', isDark),
                _buildDetailRow('Total Requests', api['requests']?.toString() ?? '0', isDark),
                _buildDetailRow('Success Rate', "${api['success_rate']}%", isDark),
                _buildDetailRow('Avg. Response Time', "${api['avg_response_time']}ms", isDark),
                _buildDetailRow('Status', api['status']?.toString() ?? 'Inactive', isDark),

                const SizedBox(height: 24),
                Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateApiDialog() {
    final prefixController = TextEditingController();
    final nameController = TextEditingController();
    final versionController = TextEditingController(text: 'v1.0');
    String category = "Student";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_link, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Create New API Route',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 20),

                    // Inputs
                    TextField(
                      controller: prefixController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'Path Prefix',
                        hintText: 'e.g. /api/sandbox',
                        prefixIcon: Icons.link,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'API Name',
                        hintText: 'e.g. Sandbox API',
                        prefixIcon: Icons.label_outline,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: versionController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'API Version',
                        hintText: 'e.g. v1.0',
                        prefixIcon: Icons.merge_type,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Dropdown for Category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                              onChanged: (val) {
                                setDialogState(() {
                                  category = val!;
                                });
                              },
                              items: ["Authentication", "Student", "Academic", "Finance", "Communication", "Others"]
                                  .map((String item) {
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (prefixController.text.isEmpty || nameController.text.isEmpty) return;
                            Navigator.pop(context);
                            try {
                              final payload = {
                                'path_prefix': prefixController.text,
                                'api_name': nameController.text,
                                'version': versionController.text,
                                'category': category,
                                'is_active': true
                              };
                              final res = await ApiService().post('/admin/schools/gateway/configs', payload);
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("API mapping ${prefixController.text} successfully created!")),
                                );
                                _fetchGatewayData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Failed to create API mapping: $e")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditApiDialog(dynamic api) {
    final nameController = TextEditingController(text: api['api_name']?.toString() ?? '');
    final versionController = TextEditingController(text: api['version']?.toString() ?? '');
    String category = api['category']?.toString() ?? 'Others';
    bool isActive = api['status']?.toString() == 'Active';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit API Route Configuration',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Path Prefix: ${api['path_prefix']}",
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Inputs
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'API Name',
                        hintText: 'e.g. Student API',
                        prefixIcon: Icons.label_outline,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: versionController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'API Version',
                        hintText: 'e.g. v1.1',
                        prefixIcon: Icons.merge_type,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                              onChanged: (val) {
                                setDialogState(() {
                                  category = val!;
                                });
                              },
                              items: ["Authentication", "Student", "Academic", "Finance", "Communication", "Others"]
                                  .map((String item) {
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Status',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Switch(
                          value: isActive,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            setDialogState(() {
                              isActive = val;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) return;
                            Navigator.pop(context);
                            try {
                              final path_prefix = api['path_prefix']?.toString() ?? '';
                              final urlPath = path_prefix.startsWith('/') ? path_prefix.substring(1) : path_prefix;
                              final payload = {
                                'api_name': nameController.text,
                                'version': versionController.text,
                                'category': category,
                                'is_active': isActive
                              };
                              final res = await ApiService().put('/admin/schools/gateway/configs/$urlPath', payload);
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API Gateway configuration updated successfully!')),
                                );
                                _fetchGatewayData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to update API config: $e')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSimulateTrafficDialog() {
    final pathController = TextEditingController(text: '/api/student/profile');
    final countController = TextEditingController(text: '150');
    final responseTimeController = TextEditingController(text: '180');
    int statusCode = 200;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.speed, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Simulate API Traffic / Load Test',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.black45, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Simulate traffic logs dynamically to observe metrics updating in real-time.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),

                    // Inputs
                    TextField(
                      controller: pathController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'API Endpoint Path',
                        hintText: 'e.g. /api/student/profile',
                        prefixIcon: Icons.shortcut,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'Number of Requests',
                        hintText: 'e.g. 150',
                        prefixIcon: Icons.numbers,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: responseTimeController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: _buildInputDecoration(
                        labelText: 'Simulated Latency (ms)',
                        hintText: 'e.g. 180',
                        prefixIcon: Icons.bolt,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Response Code',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: statusCode,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                              onChanged: (val) {
                                setDialogState(() {
                                  statusCode = val!;
                                });
                              },
                              items: [200, 400, 401, 429, 500].map((int code) {
                                return DropdownMenuItem<int>(
                                  value: code,
                                  child: Text(code.toString()),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              final count = int.tryParse(countController.text) ?? 50;
                              final latency = double.tryParse(responseTimeController.text) ?? 150.0;
                              final payload = {
                                'path': pathController.text,
                                'count': count,
                                'response_time_ms': latency,
                                'status_code': statusCode,
                                'method': 'GET'
                              };
                              final res = await ApiService().post('/admin/schools/gateway/simulate-traffic', payload);
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Successfully generated $count simulated requests!")),
                                );
                                _fetchGatewayData();
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Simulated traffic failed: $e")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Simulate', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
