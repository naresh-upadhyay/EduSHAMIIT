import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:intl/intl.dart';

class AdminInfraMonitorScreen extends StatefulWidget {
  const AdminInfraMonitorScreen({super.key});

  @override
  State<AdminInfraMonitorScreen> createState() => _AdminInfraMonitorScreenState();
}

class _AdminInfraMonitorScreenState extends State<AdminInfraMonitorScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _healthSummary = {};
  Map<String, dynamic> _gauges = {};
  List<dynamic> _servers = [];
  List<dynamic> _alerts = [];
  List<dynamic> _institutions = [];
  List<dynamic> _chartData = [];
  List<dynamic> _services = [];
  
  // Filtering & Search
  String _searchQuery = "";
  String _selectedStatus = "All Status";
  String _selectedRegion = "All Regions";
  String _selectedEnv = "All Environments";
  
  Timer? _refreshTimer;
  final TransformationController _mapTransformationController = TransformationController();

  // Inspected Server & Diagnostics State
  Map<String, dynamic>? _selectedServer;
  final List<double> _selectedServerCpuHistory = [];
  final List<double> _selectedServerRamHistory = [];
  final List<double> _selectedServerNetHistory = [];
  List<String> _terminalOutput = ["root@system:~# "];
  Timer? _terminalTimer;
  final ScrollController _terminalScrollController = ScrollController();
  final Map<String, bool> _restartingContainers = {};
  String _activeInspectorTab = "Metrics";
  final TextEditingController _terminalInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStats(showLoading: true);
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchStats(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _terminalTimer?.cancel();
    _scrollController.dispose();
    _terminalScrollController.dispose();
    _terminalInputController.dispose();
    _mapTransformationController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats({bool showLoading = true}) async {
    if (showLoading) {
      if (_metrics.isEmpty) {
        setState(() {
          _isLoading = true;
        });
      } else {
        setState(() {
          _isRefreshing = true;
        });
      }
    }
    try {
      final res = await ApiService().get('/admin/schools/infra/stats', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] ?? {};
        setState(() {
          _metrics = data['metrics'] ?? {};
          _healthSummary = data['health_summary'] ?? {};
          _gauges = data['gauges'] ?? {};
          _servers = data['servers'] ?? [];
          _alerts = data['alerts'] ?? [];
          _institutions = data['institutions_overview'] ?? [];
          _chartData = data['response_time_chart'] ?? [];
          _services = data['services_status'] ?? [];

          if (_selectedServer != null) {
            // Find updated server details
            final matched = _servers.firstWhere(
              (s) => s['name'] == _selectedServer!['name'],
              orElse: () => null,
            );
            if (matched != null) {
              _selectedServer = matched;
              // Push to history
              _selectedServerCpuHistory.add((matched['cpu_usage'] ?? 0.0).toDouble());
              _selectedServerRamHistory.add((matched['memory_usage'] ?? 0.0).toDouble());
              _selectedServerNetHistory.add((matched['network_in_out'] ?? 0.0).toDouble());
              
              if (_selectedServerCpuHistory.length > 10) _selectedServerCpuHistory.removeAt(0);
              if (_selectedServerRamHistory.length > 10) _selectedServerRamHistory.removeAt(0);
              if (_selectedServerNetHistory.length > 10) _selectedServerNetHistory.removeAt(0);
            }
          }
        });
      }
    } catch (e) {
      if (showLoading) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load telemetry stats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _selectServer(Map<String, dynamic> server) {
    setState(() {
      _selectedServer = server;
      _selectedServerCpuHistory.clear();
      _selectedServerRamHistory.clear();
      _selectedServerNetHistory.clear();
      
      // Populate with seed history
      double currentCpu = (server['cpu_usage'] ?? 40.0).toDouble();
      double currentRam = (server['memory_usage'] ?? 50.0).toDouble();
      double currentNet = (server['network_in_out'] ?? 30.0).toDouble();
      
      for (int i = 9; i >= 0; i--) {
        // Add random slight variations back in time
        _selectedServerCpuHistory.add((currentCpu - (5 - i) * 1.5).clamp(1.0, 99.0));
        _selectedServerRamHistory.add((currentRam - (5 - i) * 0.5).clamp(1.0, 99.0));
        _selectedServerNetHistory.add((currentNet - (5 - i) * 2.0).clamp(1.0, 99.0));
      }

      _terminalOutput = [
        "root@${server['name']}:~# systemctl status",
        "● ${server['name']}",
        "   State: running",
        "   Jobs: 0 queued",
        "   Failed: 0 units",
        "   Since: Mon 2026-07-12 00:15:32 UTC; 14 days ago",
        "   CGroup: /system.slice",
        "           └─docker",
        "             └─containerd",
      ];
    });
  }

  final Map<String, Color> _schoolColors = {
    'Shami Innovation Academy': const Color(0xFF10B981), 
    'EduSHAMIIT International School': const Color(0xFFF59E0B), 
    'KING INSTITUE': const Color(0xFF3B82F6), 
    'YACU': const Color(0xFFEF4444), 
    'KING JI TEST': const Color(0xFF8B5CF6), 
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;
    final isMobile = screenWidth < 950;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Infra Monitor',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                fontSize: 20,
              ),
            ),
            if (!isMobile)
              const Text(
                'Monitor infrastructure, services and performance of all institutes (Multi-tenant).',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
          ],
        ),
        actions: isMobile
            ? null
            : [
                _buildDropdownFilter(_selectedEnv, ["All Environments", "Production", "Staging", "Development"], (val) {
                  if (val != null) setState(() => _selectedEnv = val);
                }, theme, isDark),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        "${DateFormat('MMM dd').format(DateTime.now().subtract(const Duration(days: 7)))} - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _isRefreshing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black87),
                        onPressed: _fetchStats,
                        tooltip: "Refresh Diagnostics",
                      ),
                const SizedBox(width: 12),
              ],
      ),
      body: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _isLoading
                    ? const SizedBox(
                        height: 400,
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                      )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMobile) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownFilter(_selectedEnv, ["All Environments", "Production", "Staging", "Development"], (val) {
                              if (val != null) setState(() => _selectedEnv = val);
                            }, theme, isDark),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "${DateFormat('MMM dd').format(DateTime.now().subtract(const Duration(days: 7)))} - ${DateFormat('MMM dd').format(DateTime.now())}",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _isRefreshing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black87),
                                  onPressed: _fetchStats,
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 1. KPI Cards Grid
                    _buildKpiGrid(isDark, theme),
                    const SizedBox(height: 20),

                    // 2. Middle Row: Topology Map + resource utilization dials
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildHealthMapCard(isDark, theme),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 2,
                            child: _selectedServer != null
                                ? _buildNodeInspector(isDark, theme)
                                : _buildUtilizationCard(isDark, theme),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildHealthMapCard(isDark, theme),
                          const SizedBox(height: 20),
                          _selectedServer != null
                              ? _buildNodeInspector(isDark, theme)
                              : _buildUtilizationCard(isDark, theme),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // 3. Bottom Row Layout: Schools Table & Response chart on Left, Alerts & Services on Right
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column (Schools overview + Response Time chart)
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildInstitutionsTableCard(isDark, theme),
                                const SizedBox(height: 20),
                                _buildResponseTimeChartCard(isDark, theme),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Column (Active Alerts + System Status)
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildActiveAlertsCard(isDark, theme),
                                const SizedBox(height: 20),
                                _buildSystemStatusCard(isDark, theme),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildInstitutionsTableCard(isDark, theme),
                          const SizedBox(height: 20),
                          _buildResponseTimeChartCard(isDark, theme),
                          const SizedBox(height: 20),
                          _buildActiveAlertsCard(isDark, theme),
                          const SizedBox(height: 20),
                          _buildSystemStatusCard(isDark, theme),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // 4. Infrastructure Topology diagram
                    _buildTopologyCard(isDark, theme),
                  ],
                ),
              ),
            ),
    );
  }

  // Helper Filters
  Widget _buildDropdownFilter(String value, List<String> items, void Function(String?) onChanged, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: theme.cardColor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildKpiGrid(bool isDark, ThemeData theme) {
    final width = MediaQuery.of(context).size.width;
    final int crossCount = width < 750 ? 2 : (width < 1100 ? 3 : 6);
    final double aspectRatio = width < 750 ? 1.45 : (width < 1100 ? 1.3 : 1.15);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
      children: [
        _buildKpiCard(
          "Total Institutions",
          "${_metrics['total_institutions'] ?? 0}",
          "Active: ${_metrics['active_institutions'] ?? 0}",
          Icons.school_outlined,
          const Color(0xFF6366F1),
          isDark,
          theme,
        ),
        _buildKpiCard(
          "All Systems",
          "${_metrics['total_systems'] ?? 0}",
          "Healthy: ${_metrics['healthy_systems'] ?? 0}",
          Icons.dns_outlined,
          const Color(0xFF10B981),
          isDark,
          theme,
        ),
        _buildKpiCard(
          "Uptime (Avg.)",
          "${_metrics['uptime_avg'] ?? 99.9}%",
          "↑ 0.12% this week",
          Icons.trending_up,
          const Color(0xFF3B82F6),
          isDark,
          theme,
        ),
        _buildKpiCard(
          "Incidents",
          "${_metrics['incidents'] ?? 0}",
          "Active alerts in trail",
          Icons.error_outline_rounded,
          const Color(0xFFEF4444),
          isDark,
          theme,
        ),
        _buildKpiCard(
          "Total Requests",
          "${_metrics['total_requests'] ?? '0.00M'}",
          "↑ 18.6% this week",
          Icons.stacked_line_chart,
          const Color(0xFF2563EB),
          isDark,
          theme,
        ),
        _buildKpiCard(
          "Data Transfer",
          "${_metrics['data_transfer'] ?? '0.00 TB'}",
          "↑ 9.3% this week",
          Icons.cloud_upload_outlined,
          const Color(0xFFF59E0B),
          isDark,
          theme,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, String sub, IconData icon, Color color, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label, 
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sub, 
            style: TextStyle(
              color: sub.contains('↑') || sub.contains('Healthy') ? const Color(0xFF10B981) : const Color(0xFFEF4444), 
              fontSize: 9, 
              fontWeight: FontWeight.bold
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 2. Health Map Card
  Widget _buildHealthMapCard(bool isDark, ThemeData theme) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final isMobileCard = width < 600;
              return isMobileCard
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("System Health Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        const SizedBox(height: 2),
                        Text(
                          "Interactive Map: Zoom, drag and click nodes to inspect details.",
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_selectedServer != null)
                              TextButton.icon(
                                icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                label: const Text(
                                  "Clear",
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedServer = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            const SizedBox(width: 8),
                            _buildDropdownFilter(_selectedRegion, ["All Regions", "Mumbai", "Frankfurt", "Oregon", "São Paulo"], (val) {
                              if (val != null) setState(() => _selectedRegion = val);
                            }, theme, isDark),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("System Health Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                              const SizedBox(height: 2),
                              Text(
                                "Interactive Map: Zoom, drag and click nodes to inspect details.",
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (_selectedServer != null)
                              TextButton.icon(
                                icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                label: const Text(
                                  "Clear Selection",
                                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedServer = null;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            const SizedBox(width: 8),
                            _buildDropdownFilter(_selectedRegion, ["All Regions", "Mumbai", "Frankfurt", "Oregon", "São Paulo"], (val) {
                              if (val != null) setState(() => _selectedRegion = val);
                            }, theme, isDark),
                          ],
                        ),
                      ],
                    );
            }
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(
              builder: (context) {
                final width = MediaQuery.of(context).size.width;
                final isMobileCard = width < 600;
                if (isMobileCard) {
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(child: _buildMapLegendItem("Healthy", "${_healthSummary['healthy'] ?? 0}", const Color(0xFF10B981))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMapLegendItem("Warning", "${_healthSummary['warning'] ?? 0}", const Color(0xFFF59E0B))),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMapLegendItem("Critical", "${_healthSummary['critical'] ?? 0}", const Color(0xFFEF4444))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMapsStyleInfraMap(
                              servers: _servers.where((s) {
                                final r = s['region']?.toString() ?? '';
                                if (_selectedRegion != "All Regions" && _selectedRegion != r) {
                                  return false;
                                }
                                return true;
                              }).toList(),
                              selectedServer: _selectedServer,
                              isDark: isDark,
                              transformationController: _mapTransformationController,
                              onServerSelected: (s) {
                                _selectServer(s);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMapLegendItem("Healthy", "${_healthSummary['healthy'] ?? 0}", const Color(0xFF10B981)),
                          const SizedBox(height: 12),
                          _buildMapLegendItem("Warning", "${_healthSummary['warning'] ?? 0}", const Color(0xFFF59E0B)),
                          const SizedBox(height: 12),
                          _buildMapLegendItem("Critical", "${_healthSummary['critical'] ?? 0}", const Color(0xFFEF4444)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMapsStyleInfraMap(
                            servers: _servers.where((s) {
                              final r = s['region']?.toString() ?? '';
                              if (_selectedRegion != "All Regions" && _selectedRegion != r) {
                                return false;
                              }
                              return true;
                            }).toList(),
                            selectedServer: _selectedServer,
                            isDark: isDark,
                            transformationController: _mapTransformationController,
                            onServerSelected: (s) {
                              _selectServer(s);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegendItem(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _executeTerminalCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    final cleanCmd = cmd.trim();
    final lowerCmd = cleanCmd.toLowerCase();
    
    setState(() {
      _terminalOutput.add("root@${_selectedServer?['name'] ?? 'system'}:~# $cleanCmd");
    });
    
    _terminalInputController.clear();
    _scrollTerminalToBottom();

    if (lowerCmd == 'clear') {
      setState(() {
        _terminalOutput.clear();
      });
      return;
    }
    
    if (lowerCmd == 'help') {
      setState(() {
        _terminalOutput.addAll([
          "Available Commands:",
          "  help               - Show this help menu",
          "  status             - Show system status and metrics summary",
          "  clear              - Clear the terminal screen",
          "  [system commands]  - Run any host OS shell command (e.g. restart docker, docker ps, df, whoami)"
        ]);
      });
      _scrollTerminalToBottom();
      return;
    }

    try {
      final res = await ApiService().post('/admin/schools/infra/terminal/run', {
        'server_name': _selectedServer?['name'] ?? 'host',
        'command': cleanCmd,
      });

      if (res['success'] == true) {
        final String output = res['output'] ?? '';
        setState(() {
          _terminalOutput.addAll(output.split('\n'));
        });
      } else {
        setState(() {
          _terminalOutput.add("Error running command: ${res['message']}");
        });
      }
    } catch (e) {
      setState(() {
        _terminalOutput.add("API Error: $e");
      });
    } finally {
      _scrollTerminalToBottom();
    }
  }

  void _scrollTerminalToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildNodeInspector(bool isDark, ThemeData theme) {
    final server = _selectedServer;
    if (server == null) return const SizedBox.shrink();

    Color statusColor = const Color(0xFF10B981);
    if (server['status'] == 'warning') statusColor = const Color(0xFFF59E0B);
    if (server['status'] == 'critical') statusColor = const Color(0xFFEF4444);

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              server['name'] ?? 'Node Inspector',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Outfit'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${server['ip_address'] ?? '0.0.0.0'} • ${server['region'] ?? 'Unknown Region'}",
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedServer = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Tab bar
          Container(
            height: 36,
            color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
            child: Row(
              children: ["Metrics", "Services", "Console"].map((tab) {
                final isSelected = _activeInspectorTab == tab;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeInspectorTab = tab;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Tab Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildActiveTabContent(isDark, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDark, ThemeData theme) {
    if (_activeInspectorTab == "Services") {
      return _buildInspectorServicesTab(isDark, theme);
    } else if (_activeInspectorTab == "Console") {
      return _buildInspectorConsoleTab(isDark, theme);
    }
    return _buildInspectorMetricsTab(isDark, theme);
  }

  Widget _buildInspectorMetricsTab(bool isDark, ThemeData theme) {
    final server = _selectedServer;
    if (server == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Small metric pills
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInspectorMetricPill("CPU", "${server['cpu_usage']}%", const Color(0xFFEF4444)),
            _buildInspectorMetricPill("RAM", "${server['memory_usage']}%", const Color(0xFF3B82F6)),
            _buildInspectorMetricPill("Network", "${server['network_in_out']} MB/s", const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Performance History (Real-Time)",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 9,
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(_selectedServerCpuHistory.length, (index) {
                    return FlSpot(index.toDouble(), _selectedServerCpuHistory[index]);
                  }),
                  isCurved: true,
                  color: const Color(0xFFEF4444),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(_selectedServerRamHistory.length, (index) {
                    return FlSpot(index.toDouble(), _selectedServerRamHistory[index]);
                  }),
                  isCurved: true,
                  color: const Color(0xFF3B82F6),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInspectorMetricPill(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _controlService(String serverName, String serviceName, String action) async {
    final key = "${serverName}_$serviceName";
    
    // Map service name to real clean Docker container name on the host system
    String cmdName = "";
    if (serviceName.contains("Nginx")) cmdName = "edushamiit-nginx";
    else if (serviceName.contains("Node")) cmdName = "edushamiit-api";
    else if (serviceName.contains("Postgres")) cmdName = "supabase-db";
    else if (serviceName.contains("Redis")) cmdName = "edushamiit-redis";
    else cmdName = serviceName.toLowerCase().replaceAll(' ', '_');
    
    // Simulate terminal command log for realism
    if (action == 'restart') {
      _executeTerminalCommand("docker restart $cmdName");
    } else if (action == 'stop') {
      _executeTerminalCommand("docker stop $cmdName");
    } else if (action == 'start') {
      _executeTerminalCommand("docker start $cmdName");
    }

    setState(() {
      if (action == 'restart') {
        _restartingContainers[key] = true;
      }
    });

    try {
      final res = await ApiService().post('/admin/schools/infra/services/control', {
        'server_name': serverName,
        'service_name': serviceName,
        'action': action,
      });

      if (res['success'] == true) {
        _fetchStats(showLoading: false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to control service: ${res['message']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error controlling service: $e')),
        );
      }
    } finally {
      if (action == 'restart') {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _restartingContainers[key] = false;
            });
          }
        });
      }
    }
  }

  Widget _buildInspectorServicesTab(bool isDark, ThemeData theme) {
    final serverName = _selectedServer?['name'] ?? '';
    List<dynamic> serverServices = _services.where((s) => s['host_server'] == serverName).toList();
    if (serverServices.isEmpty) {
      serverServices = [
        {'name': 'Web Server (Nginx)', 'status': 'running', 'port': 80},
        {'name': 'Application API (Node)', 'status': 'running', 'port': 8000},
        {'name': 'Database Host (Postgres)', 'status': 'running', 'port': 5432},
        {'name': 'Cache Broker (Redis)', 'status': 'running', 'port': 6379},
      ];
    }

    return ListView.separated(
      itemCount: serverServices.length,
      separatorBuilder: (context, index) => const Divider(height: 12, thickness: 0.5),
      itemBuilder: (context, index) {
        final s = serverServices[index];
        final name = s['name'] ?? '';
        final status = s['status'] ?? 'running';
        final port = s['port'] ?? 80;
        final key = "${serverName}_$name";
        final isRestarting = _restartingContainers[key] ?? false;

        Color indicatorColor = const Color(0xFF10B981);
        if (status == 'warning' || status == 'restarting') indicatorColor = const Color(0xFFF59E0B);
        if (status == 'stopped') indicatorColor = const Color(0xFFEF4444);

        final isStopped = status == 'stopped';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (isRestarting || status == 'restarting')
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                    )
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("Port: $port • Protocol: TCP", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  (isRestarting || status == 'restarting') ? "RESTARTING" : status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: (isRestarting || status == 'restarting') ? const Color(0xFF4F46E5) : indicatorColor,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) => _controlService(serverName, name, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'restart',
                      child: Text('Restart Container', style: TextStyle(fontSize: 11)),
                    ),
                    if (isStopped)
                      const PopupMenuItem(
                        value: 'start',
                        child: Text('Start Service', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                      )
                    else
                      const PopupMenuItem(
                        value: 'stop',
                        child: Text('Stop Service', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildInspectorConsoleTab(bool isDark, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              controller: _terminalScrollController,
              itemCount: _terminalOutput.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _terminalOutput[index],
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontFamily: 'Courier New',
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              "root@${_selectedServer?['name'] ?? 'system'}:~# ",
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontFamily: 'Courier New',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 28,
                child: TextField(
                  controller: _terminalInputController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontFamily: 'Courier New',
                    fontSize: 11,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: _executeTerminalCommand,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Resource Utilization Card
  Widget _buildUtilizationCard(bool isDark, ThemeData theme) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resource Utilization (Average)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          const SizedBox(height: 20),
          Expanded(
            child: Builder(
              builder: (context) {
                final cpuVal = (_gauges['cpu'] ?? 42.0).toDouble();
                final memVal = (_gauges['memory'] ?? 61.0).toDouble();
                final diskVal = (_gauges['disk'] ?? 54.0).toDouble();
                final netVal = (_gauges['network'] ?? 35.0).toDouble();

                String getStatus(double val) => val >= 85.0 ? "Critical" : (val >= 70.0 ? "Warning" : "Normal");
                Color getColor(double val) => val >= 85.0 ? const Color(0xFFEF4444) : (val >= 70.0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.35,
                  children: [
                    FittedBox(fit: BoxFit.scaleDown, child: _buildUtilGauge("CPU Usage", cpuVal, getStatus(cpuVal), getColor(cpuVal), isDark)),
                    FittedBox(fit: BoxFit.scaleDown, child: _buildUtilGauge("Memory Usage", memVal, getStatus(memVal), getColor(memVal), isDark)),
                    FittedBox(fit: BoxFit.scaleDown, child: _buildUtilGauge("Disk Usage", diskVal, getStatus(diskVal), getColor(diskVal), isDark)),
                    FittedBox(fit: BoxFit.scaleDown, child: _buildUtilGauge("Network I/O", netVal, getStatus(netVal), getColor(netVal), isDark)),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilGauge(String label, double value, String status, Color color, bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: CircularProgressIndicator(
                value: value / 100.0,
                strokeWidth: 6,
                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                color: value > 80 ? const Color(0xFFEF4444) : (value > 60 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${value.toStringAsFixed(0)}%",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'),
                ),
                Text(
                  value > 80 ? "Critical" : (value > 60 ? "Warning" : "Normal"),
                  style: TextStyle(
                    color: value > 80 ? const Color(0xFFEF4444) : (value > 60 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 4. Institutions Table Card
  Widget _buildInstitutionsTableCard(bool isDark, ThemeData theme) {
    // Filter list
    final filtered = _institutions.where((inst) {
      final name = inst['name'].toString().toLowerCase();
      final status = inst['status'].toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesQuery = name.contains(q);
      final matchesStatus = _selectedStatus == "All Status" || status == _selectedStatus.toLowerCase();
      return matchesQuery && matchesStatus;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final isMobileCard = width < 600;
              return isMobileCard
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Institutions Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: const InputDecoration(
                                  hintText: "Search institution...",
                                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            _buildDropdownFilter(_selectedStatus, ["All Status", "Healthy", "Warning", "Critical"], (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            }, theme, isDark),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Institutions Overview", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        Row(
                          children: [
                            Container(
                              width: 200,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: const InputDecoration(
                                  hintText: "Search institution...",
                                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildDropdownFilter(_selectedStatus, ["All Status", "Healthy", "Warning", "Critical"], (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            }, theme, isDark),
                          ],
                        ),
                      ],
                    );
            }
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.4),
                  4: FlexColumnWidth(1.4),
                  5: FlexColumnWidth(1.8),
                  6: FlexColumnWidth(1.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)))),
                    children: const [
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Institution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Uptime", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Resp. Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Requests (24h)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Storage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                      Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("Alerts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    ],
                  ),
                  ...filtered.map<TableRow>((inst) {
                    Color statusColor = const Color(0xFF10B981);
                    if (inst['status'] == 'Warning') statusColor = const Color(0xFFF59E0B);
                    if (inst['status'] == 'Critical') statusColor = const Color(0xFFEF4444);

                    return TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.business_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  inst['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text(inst['status'], style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(inst['uptime'], style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(inst['response_time'], style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(inst['requests'], style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(inst['storage'], style: const TextStyle(fontSize: 12))),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: inst['alerts'] > 0 ? const Color(0xFFEF4444) : Colors.grey, size: 14),
                              const SizedBox(width: 4),
                              Text("${inst['alerts']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: inst['alerts'] > 0 ? const Color(0xFFEF4444) : Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
        ],
      ),
    );
  }

  // 5. Response Time Line Chart
  Widget _buildResponseTimeChartCard(bool isDark, ThemeData theme) {
    List<LineChartBarData> bars = [];
    final schools = _schoolColors.keys.toList();
    
    for (var sName in schools) {
      Color color = _schoolColors[sName] ?? const Color(0xFF6366F1);
      List<FlSpot> spots = [];
      for (int i = 0; i < _chartData.length; i++) {
        var entry = _chartData[i];
        double val = (entry[sName] ?? 0).toDouble();
        spots.add(FlSpot(i.toDouble(), val));
      }
      if (spots.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ));
      }
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final isMobileCard = width < 600;
              return isMobileCard
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Response Time (Avg.)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _schoolColors.keys.map((school) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: _schoolColors[school], shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    Text(school.split(' ').first, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Response Time (Avg.)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        Row(
                          children: _schoolColors.keys.map((school) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _schoolColors[school], shape: BoxShape.circle)),
                                  const SizedBox(width: 4),
                                  Text(school.split(' ').first, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
            }
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) => Text("${value.toInt()}ms", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < _chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_chartData[idx]['label'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: bars,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Active Alerts Card (Right Sidebar)
  Widget _buildActiveAlertsCard(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Active Alerts", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                    child: Text("${_alerts.length}", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Text("View All", style: TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (_alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text("No active incidents found.", style: TextStyle(color: Colors.grey, fontSize: 12))),
            )
          else
            ..._alerts.map((a) {
              Color severityColor = a['severity'] == 'critical' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.warning_amber_rounded, color: severityColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text("Institute: ${a['institute']}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text(
                      "Active",
                      style: TextStyle(color: severityColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // 7. System Status Card
  Widget _buildSystemStatusCard(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("System Status", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          ..._services.map((srv) {
            Color statusColor = srv['status'] == 'operational' ? const Color(0xFF10B981) : const Color(0xFFEF4444);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.network_ping, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 10),
                      Text(srv['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        srv['status'] == 'operational' ? "Operational" : "Incident",
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 8. Infrastructure Topology Card
  Widget _buildTopologyCard(bool isDark, ThemeData theme) {
    final steps = [
      _buildTopologyStep("Users", "Web / Mobile", Icons.person_outline, isDark),
      _buildTopologyStep("Cloudflare", "CDN & WAF", Icons.cloud_queue, isDark),
      _buildTopologyStep("Load Balancer", "HAProxy Nodes", Icons.dns_outlined, isDark),
      _buildTopologyStep("API Gateway", "Kong Gateway", Icons.settings_input_component, isDark),
      _buildTopologyStep("Microservices", "12 Core Services", Icons.widgets_outlined, isDark),
      _buildTopologyStep("Databases", "Postgres Cluster", Icons.storage, isDark),
      _buildTopologyStep("Storage", "AWS S3 / minio", Icons.cloud_done_outlined, isDark),
      _buildTopologyStep("Backup", "Daily snapshot", Icons.backup_outlined, isDark),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Infrastructure Topology", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text("All Systems Operational", style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(steps.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                  );
                }
                return steps[index ~/ 2];
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyStep(String label, String detail, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(color: Colors.grey, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Map Backdrop Grid
class GridPainter extends CustomPainter {
  final bool isDark;
  GridPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    double gridSpace = 20.0;
    for (double i = 0; i < size.width; i += gridSpace) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += gridSpace) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleMapsStyleInfraMap extends StatefulWidget {
  final List<dynamic> servers;
  final Map<String, dynamic>? selectedServer;
  final bool isDark;
  final TransformationController transformationController;
  final Function(Map<String, dynamic>) onServerSelected;

  const GoogleMapsStyleInfraMap({
    super.key,
    required this.servers,
    required this.selectedServer,
    required this.isDark,
    required this.transformationController,
    required this.onServerSelected,
  });

  @override
  State<GoogleMapsStyleInfraMap> createState() => _GoogleMapsStyleInfraMapState();
}

class _GoogleMapsStyleInfraMapState extends State<GoogleMapsStyleInfraMap> {
  TapDownDetails? _doubleTapDetails;

  static const double _mapW = 900;
  static const double _mapH = 400;

  // Equirectangular pin positions on the real world map image
  Offset _pinFor(String region) {
    switch (region) {
      case "Oregon":     return const Offset(150, 115);
      case "Frankfurt":  return const Offset(470,  95);
      case "Mumbai":     return const Offset(632, 175);
      case "São Paulo":  return const Offset(320, 270);
      default:           return const Offset(450, 200);
    }
  }

  void _handleDoubleTap() {
    if (widget.transformationController.value != Matrix4.identity()) {
      widget.transformationController.value = Matrix4.identity();
    } else if (_doubleTapDetails != null) {
      final pos = _doubleTapDetails!.localPosition;
      widget.transformationController.value =
          Matrix4.translationValues(-pos.dx * 0.8, -pos.dy * 0.8, 0.0)
            ..scale(1.8, 1.8, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: widget.transformationController,
          constrained: false,           // ← child can exceed viewport; enables real panning
          boundaryMargin: EdgeInsets.zero,
          minScale: 0.6,
          maxScale: 5.0,
          child: SizedBox(
            width: _mapW,
            height: _mapH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Background fill ──────────────────────────────────
                Positioned.fill(
                  child: Container(
                    color: widget.isDark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFE8F0FE),
                  ),
                ),
                // ── Grid lines ───────────────────────────────────────
                Positioned.fill(
                  child: CustomPaint(painter: GridPainter(widget.isDark)),
                ),
                // ── Real World Map outline ───────────────────────────
                Positioned.fill(
                  child: Image.network(
                    'world_map.png',
                    fit: BoxFit.fill,
                    color: widget.isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.blueGrey.withValues(alpha: 0.4),
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback in case image fails to load
                      return CustomPaint(
                        painter: ContinentsPainter(widget.isDark),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                          strokeWidth: 2,
                        ),
                      );
                    },
                  ),
                ),
                // ── Network connection arcs ───────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: NetworkConnectionsPainter(
                      servers: widget.servers,
                      selectedServer: widget.selectedServer,
                      mapW: _mapW,
                      mapH: _mapH,
                    ),
                  ),
                ),
                // ── Server pins ───────────────────────────────────────
                ...widget.servers.map((s) {
                  final region = s['region']?.toString() ?? '';
                  final pin = _pinFor(region);

                  Color color = const Color(0xFF10B981);
                  if (s['status'] == 'warning')  color = const Color(0xFFF59E0B);
                  if (s['status'] == 'critical') color = const Color(0xFFEF4444);

                  final isSelected = widget.selectedServer?['name'] == s['name'];
                  final cpu = s['cpu_usage']?.toString() ?? '–';
                  final ram = s['memory_usage']?.toString() ?? '–';

                  return Positioned(
                    left: pin.dx - 44,
                    top:  pin.dy - 44,
                    child: GestureDetector(
                      onTap: () => widget.onServerSelected(Map<String, dynamic>.from(s)),
                      child: SizedBox(
                        width: 88,
                        height: 105,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            // Outer pulse ring
                            Positioned(
                              top: 20,
                              left: 20,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 8.0, end: isSelected ? 28.0 : 20.0),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeInOut,
                                builder: (_, val, __) => Container(
                                  width: val,
                                  height: val,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: isSelected ? 0.3 : 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            // Selected ring border
                            if (isSelected)
                              Positioned(
                                top: 15,
                                left: 15,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color, width: 2),
                                  ),
                                ),
                              ),
                            // Core dot
                            Positioned(
                              top: 29,
                              left: 29,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.85),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Label bubble below dot
                            Positioned(
                              top: 50,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? color
                                        : (widget.isDark
                                            ? Colors.white12
                                            : Colors.black12),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      s['name'] ?? region,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '$cpu% CPU · $ram% RAM',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected ? color : Colors.grey,
                                        fontSize: 6,
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
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NetworkConnectionsPainter extends CustomPainter {
  final List<dynamic> servers;
  final Map<String, dynamic>? selectedServer;
  final double mapW;
  final double mapH;

  NetworkConnectionsPainter({
    required this.servers,
    this.selectedServer,
    this.mapW = 900,
    this.mapH = 400,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const Map<String, Offset> coords = {
      "Oregon":    Offset(150, 115),
      "Frankfurt": Offset(470,  95),
      "Mumbai":    Offset(632, 175),
      "São Paulo": Offset(320, 270),
    };

    final regions = coords.keys.toList();
    for (int i = 0; i < regions.length; i++) {
      for (int j = i + 1; j < regions.length; j++) {
        final start = coords[regions[i]]!;
        final end = coords[regions[j]]!;

        final path = Path();
        path.moveTo(start.dx, start.dy);
        
        final controlPoint = Offset(
          (start.dx + end.dx) / 2,
          (start.dy + end.dy) / 2 - 30,
        );
        path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);

        bool isPathSelected = false;
        if (selectedServer != null) {
          final selRegion = selectedServer!['region']?.toString() ?? '';
          if (selRegion == regions[i] || selRegion == regions[j]) {
            isPathSelected = true;
          }
        }

        if (isPathSelected) {
          canvas.drawPath(path, activePaint);
        } else {
          canvas.drawPath(path, dashPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ContinentsPainter extends CustomPainter {
  final bool isDark;
  ContinentsPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ocean background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = isDark
            ? const Color(0xFF0D1B2A)
            : const Color(0xFFCFE2F3),
    );

    final landFill = Paint()
      ..color = isDark
          ? const Color(0xFF1A2E1A)
          : const Color(0xFFA8C5A0)
      ..style = PaintingStyle.fill;

    final landBorder = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.green.withValues(alpha: 0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    void draw(Path p) {
      canvas.drawPath(p, landFill);
      canvas.drawPath(p, landBorder);
    }

    // North America  (upper-left quadrant)
    draw(Path()
      ..moveTo(w * 0.07, h * 0.10)
      ..lineTo(w * 0.22, h * 0.06)
      ..lineTo(w * 0.28, h * 0.16)
      ..lineTo(w * 0.30, h * 0.38)
      ..lineTo(w * 0.24, h * 0.44)
      ..lineTo(w * 0.17, h * 0.40)
      ..lineTo(w * 0.13, h * 0.30)
      ..close());

    // Central America stub
    draw(Path()
      ..moveTo(w * 0.24, h * 0.44)
      ..lineTo(w * 0.27, h * 0.50)
      ..lineTo(w * 0.23, h * 0.54)
      ..lineTo(w * 0.20, h * 0.50)
      ..close());

    // South America
    draw(Path()
      ..moveTo(w * 0.24, h * 0.55)
      ..lineTo(w * 0.31, h * 0.56)
      ..lineTo(w * 0.36, h * 0.65)
      ..lineTo(w * 0.33, h * 0.82)
      ..lineTo(w * 0.26, h * 0.90)
      ..lineTo(w * 0.21, h * 0.75)
      ..lineTo(w * 0.22, h * 0.60)
      ..close());

    // Europe
    draw(Path()
      ..moveTo(w * 0.42, h * 0.10)
      ..lineTo(w * 0.52, h * 0.08)
      ..lineTo(w * 0.55, h * 0.20)
      ..lineTo(w * 0.50, h * 0.36)
      ..lineTo(w * 0.43, h * 0.38)
      ..lineTo(w * 0.40, h * 0.28)
      ..close());

    // Asia (large)
    draw(Path()
      ..moveTo(w * 0.52, h * 0.08)
      ..lineTo(w * 0.80, h * 0.05)
      ..lineTo(w * 0.92, h * 0.12)
      ..lineTo(w * 0.90, h * 0.38)
      ..lineTo(w * 0.78, h * 0.46)
      ..lineTo(w * 0.66, h * 0.44)
      ..lineTo(w * 0.55, h * 0.36)
      ..lineTo(w * 0.52, h * 0.20)
      ..close());

    // Africa
    draw(Path()
      ..moveTo(w * 0.43, h * 0.38)
      ..lineTo(w * 0.54, h * 0.38)
      ..lineTo(w * 0.58, h * 0.48)
      ..lineTo(w * 0.56, h * 0.70)
      ..lineTo(w * 0.50, h * 0.82)
      ..lineTo(w * 0.44, h * 0.72)
      ..lineTo(w * 0.40, h * 0.52)
      ..close());

    // Indian subcontinent
    draw(Path()
      ..moveTo(w * 0.62, h * 0.40)
      ..lineTo(w * 0.68, h * 0.38)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.65, h * 0.60)
      ..lineTo(w * 0.61, h * 0.52)
      ..close());

    // Southeast Asia (stub)
    draw(Path()
      ..moveTo(w * 0.78, h * 0.46)
      ..lineTo(w * 0.85, h * 0.44)
      ..lineTo(w * 0.84, h * 0.58)
      ..lineTo(w * 0.78, h * 0.56)
      ..close());

    // Australia
    draw(Path()
      ..moveTo(w * 0.75, h * 0.62)
      ..lineTo(w * 0.88, h * 0.60)
      ..lineTo(w * 0.90, h * 0.80)
      ..lineTo(w * 0.80, h * 0.85)
      ..lineTo(w * 0.72, h * 0.76)
      ..close());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
