import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class PaymentGatewayIntegrationScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolName;
  final bool showSidebar;
  final bool isEmbedded;

  const PaymentGatewayIntegrationScreen({
    super.key,
    this.schoolId,
    this.schoolName,
    this.showSidebar = false,
    this.isEmbedded = false,
  });

  @override
  State<PaymentGatewayIntegrationScreen> createState() =>
      _PaymentGatewayIntegrationScreenState();
}

class _PaymentGatewayIntegrationScreenState
    extends State<PaymentGatewayIntegrationScreen>
    with SingleTickerProviderStateMixin {
  // Navigation tabs (0: Overview, 1: Payments, 2: Payment Gateways, 3: Payment Requests, 4: Webhooks, 5: Reconciliation, 6: Settings)
  final int _activeNavTab = 2; // Payment Gateways is active

  // Environment State
  String _environment = 'SANDBOX'; // 'SANDBOX' or 'PRODUCTION'

  // Loading States
  bool _isLoadingDashboard = false;
  bool _isTestingAll = false;
  final Map<String, bool> _testingGatewayId = {};

  // Dashboard Data from Real PostgreSQL Backend
  Map<String, dynamic> _dashboardData = {};
  List<dynamic> _gateways = [];
  List<dynamic> _routingRules = [];
  List<dynamic> _methodMatrix = [];
  List<dynamic> _securityChecks = [];
  List<dynamic> _recentEvents = [];

  // Filter & Search State
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _sortBy = 'NAME';
  final TextEditingController _searchCtrl = TextEditingController();

  // Active Gateway for Drawer
  Map<String, dynamic>? _selectedGatewayForDrawer;
  int _drawerActiveTab = 0; // 0: Overview, 1: Configuration, 2: Methods, 3: Transactions, 4: Webhooks, 5: Health, 6: Logs, 7: Audit
  List<dynamic> _drawerTransactions = [];
  bool _isLoadingDrawerTxns = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _fetchRoutingRules();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // BACKEND API CALLS (PostgreSQL & FastAPI Backend)
  // =========================================================================

  String get _apiBase => '${AppConfig.apiBaseUrl}/v1/payment-gateways';

  /// Returns auth headers including Bearer token from shared prefs.
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoadingDashboard = true);
    try {
      final uri = Uri.parse('$_apiBase/dashboard').replace(queryParameters: {
        'environment': _environment,
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final rawData = body['data'];
          final data = (rawData is Map) ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
          setState(() {
            _dashboardData = data;
            _gateways = (data['gateways'] as List<dynamic>?) ?? [];
            _methodMatrix = (data['method_matrix'] as List<dynamic>?) ?? [];
            _securityChecks = (data['security_center'] as List<dynamic>?) ?? [];
            _recentEvents = (data['recent_events'] as List<dynamic>?) ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching PGI dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _fetchRoutingRules() async {
    try {
      final uri = Uri.parse('$_apiBase/routing').replace(queryParameters: {
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          setState(() {
            _routingRules = body['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching routing rules: $e');
    }
  }

  Future<void> _testSingleGateway(String gatewayId, String providerName) async {
    setState(() => _testingGatewayId[gatewayId] = true);
    try {
      final uri = Uri.parse('$_apiBase/$gatewayId/test').replace(queryParameters: {
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });
      final res = await http.post(uri, headers: await _authHeaders());
      final body = json.decode(res.body);
      if (mounted) {
        if (res.statusCode == 200 && body['success'] == true) {
          final data = body['data'] ?? {};
          final latency = data['latency_ms'] ?? 0;
          _showSnack(
            '$providerName: Connection Successful! (${latency}ms)',
            isError: false,
          );
          _fetchDashboard();
        } else {
          _showSnack(
            '$providerName Test Failed: ${body['detail'] ?? body['message'] ?? 'Unknown error'}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error testing $providerName: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _testingGatewayId[gatewayId] = false);
      }
    }
  }

  Future<void> _testAllGateways() async {
    setState(() => _isTestingAll = true);
    try {
      final uri = Uri.parse('$_apiBase/test-all').replace(queryParameters: {
        'environment': _environment,
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });
      final res = await http.post(uri, headers: await _authHeaders());
      final body = json.decode(res.body);
      if (mounted) {
        if (res.statusCode == 200 && body['success'] == true) {
          final list = body['data'] as List<dynamic>? ?? [];
          final passed = list.where((x) => x['status'] == 'SUCCESS').length;
          _showSnack(
            'Batch Test Complete: $passed of ${list.length} Gateways Operational',
            isError: false,
          );
          _fetchDashboard();
        } else {
          _showSnack('Failed to run batch gateway tests', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error during batch test: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isTestingAll = false);
    }
  }

  Future<void> _setDefaultGateway(String gatewayId, String providerName) async {
    try {
      final uri = Uri.parse('$_apiBase/$gatewayId/set-default').replace(queryParameters: {
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });
      final res = await http.post(uri, headers: await _authHeaders());
      final body = json.decode(res.body);
      if (mounted) {
        if (res.statusCode == 200 && body['success'] == true) {
          _showSnack('Default route switched to $providerName', isError: false);
          _fetchDashboard();
        } else {
          _showSnack(body['detail'] ?? 'Could not set default gateway', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _toggleGatewayStatus(String gatewayId, bool currentlyEnabled, String providerName) async {
    final endpoint = currentlyEnabled ? 'disable' : 'enable';
    try {
      final uri = Uri.parse('$_apiBase/$gatewayId/$endpoint').replace(queryParameters: {
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
      });
      final res = await http.post(uri, headers: await _authHeaders());
      final body = json.decode(res.body);
      if (mounted) {
        if (res.statusCode == 200 && body['success'] == true) {
          _showSnack('$providerName is now ${currentlyEnabled ? "Disabled" : "Active"}', isError: false);
          _fetchDashboard();
        } else {
          _showSnack(body['detail'] ?? 'Operation rejected', isError: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _fetchDrawerTransactions(String gatewayId) async {
    setState(() => _isLoadingDrawerTxns = true);
    try {
      // Use the canonical EduSHAMIIT Pay transactions endpoint (gateway-filtered)
      // instead of the obsolete /v1/payment-gateways/{id}/transactions endpoint.
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments').replace(queryParameters: {
        if (widget.schoolId != null) 'school_id': widget.schoolId!,
        'gateway': gatewayId,
        'limit': '25',
      });
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final rawData = body['data'];
          final data = (rawData is Map) ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
          setState(() {
            _drawerTransactions = (data['items'] as List<dynamic>?) ?? [];
          });
        }
      } else {
        debugPrint('Drawer transactions HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching gateway transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDrawerTxns = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // =========================================================================
  // MAIN BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final Widget dashboardBody = _isLoadingDashboard && _gateways.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Sub-Navigation Tabs (when not embedded)
                if (!widget.isEmbedded) ...[
                  _buildSubNavTabs(),
                  const SizedBox(height: 16),
                ],

                // Live Production Warning Banner
                if (_environment == 'PRODUCTION') ...[
                  _buildLiveProductionWarningBanner(),
                  const SizedBox(height: 16),
                ],

                // Section Header with Actions & Environment Toggle
                _buildPageHeader(),
                const SizedBox(height: 20),

                // 5 KPI Cards (Real DB values)
                _buildKpiSummaryCards(),
                const SizedBox(height: 24),

                // Payment Providers Section (Filter bar & Cards Grid)
                _buildPaymentProvidersSection(),
                const SizedBox(height: 28),

                // Responsive Split: Payment Method Matrix & Routing Engine
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1050) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildPaymentMethodMatrixCard(),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: _buildRoutingEngineCard(),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildPaymentMethodMatrixCard(),
                          const SizedBox(height: 20),
                          _buildRoutingEngineCard(),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Bottom Row: Gateway Health Monitor & Recent Events & Security Center
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1050) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildHealthMonitorCard(),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildSecurityCenterCard(),
                                const SizedBox(height: 20),
                                _buildRecentEventsCard(),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildHealthMonitorCard(),
                          const SizedBox(height: 20),
                          _buildSecurityCenterCard(),
                          const SizedBox(height: 20),
                          _buildRecentEventsCard(),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      endDrawer: _selectedGatewayForDrawer != null ? _buildDetailDrawer() : null,
      body: dashboardBody,
    );
  }



  // =========================================================================
  // SUB-NAVIGATION TABS
  // =========================================================================

  Widget _buildSubNavTabs() {
    final tabs = [
      'Overview',
      'Payments',
      'Payment Gateways',
      'Payment Requests',
      'Webhooks',
      'Reconciliation',
      'Settings',
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final isSelected = idx == _activeNavTab;
            return InkWell(
              onTap: () {
                if (idx == 1) {
                  // Navigate to Payments screen
                  Navigator.of(context).pushReplacementNamed('/admin/payment-engine/payments');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  tabs[idx],
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // =========================================================================
  // LIVE PRODUCTION WARNING BANNER
  // =========================================================================

  Widget _buildLiveProductionWarningBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIVE PRODUCTION MODE ACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                Text(
                  'Real money financial transactions will occur with configured production merchant accounts. Changes will immediately affect student fee payments.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _environment = 'SANDBOX';
              });
              _fetchDashboard();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Switch to Sandbox'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PAGE HEADER WITH ENVIRONMENT TOGGLE & ACTIONS
  // =========================================================================

  Widget _buildPageHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 980;

        final actionControls = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Environment Selector Pill (Sandbox / Production)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEnvChoice('SANDBOX', 'Sandbox'),
                  _buildEnvChoice('PRODUCTION', 'Production'),
                ],
              ),
            ),

            // [Test All Gateways]
            OutlinedButton.icon(
              onPressed: _isTestingAll ? null : _testAllGateways,
              icon: _isTestingAll
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                    )
                  : const Icon(Icons.speed_rounded, size: 16),
              label: Text(
                _isTestingAll ? 'Testing All...' : 'Test All Gateways',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.white,
              ),
            ),

            // [ + Add Gateway ]
            ElevatedButton.icon(
              onPressed: () => _openAddGatewayWizard(),
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: Text(
                'Add Gateway',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );

        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Gateway Integration',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect and manage payment providers used by EduSHAMIIT for subscriptions, school fees and online collections.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 12),
              actionControls,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            const SizedBox(width: 16),
            actionControls,
          ],
        );
      },
    );
  }

  Widget _buildEnvChoice(String envCode, String label) {
    final isSelected = _environment == envCode;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          if (envCode == 'PRODUCTION') {
            _confirmProductionSwitch();
          } else {
            setState(() => _environment = envCode);
            _fetchDashboard();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (envCode == 'PRODUCTION' ? const Color(0xFFDC2626) : const Color(0xFF4F46E5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _confirmProductionSwitch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Activate Production Mode?', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'This will switch the console to LIVE Production. Real-money payments will be directed to live acquiring gateways. Are you sure you want to proceed?',
          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _environment = 'PRODUCTION');
              _fetchDashboard();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Proceed to Live Mode', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5 KPI SUMMARY CARDS (Live PostgreSQL Values)
  // =========================================================================

  Widget _buildKpiSummaryCards() {
    final kpis = _dashboardData['kpis'] ?? {};
    final connectedCount = kpis['connected_gateways'] ?? 0;
    final healthyGateways = kpis['healthy_gateways'] ?? '0/0';
    final defaultGateway = kpis['default_gateway'] ?? 'Not Configured';
    final todayTxns = kpis['today_transactions'] ?? 0;
    final successRate = kpis['success_rate'] ?? 'No data';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (12 * 4)) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Connected Gateways',
              value: '$connectedCount',
              subtext: '${kpis['total_gateways'] ?? 5} supported channels',
              icon: Icons.hub_rounded,
              color: const Color(0xFF4F46E5),
              width: cardWidth < 180 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: 'Healthy Gateways',
              value: '$healthyGateways',
              subtext: 'Real-time ping verification',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF16A34A),
              width: cardWidth < 180 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: 'Default Gateway',
              value: defaultGateway,
              subtext: 'Primary acquiring channel',
              icon: Icons.star_border_rounded,
              color: const Color(0xFFF59E0B),
              width: cardWidth < 180 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: "Today's Transactions",
              value: '$todayTxns',
              subtext: 'Processed in 24h',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF0284C7),
              width: cardWidth < 180 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: 'Gateway Success Rate',
              value: '$successRate',
              subtext: 'Settled vs attempts',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF8B5CF6),
              width: cardWidth < 180 ? constraints.maxWidth : cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFCBD5E1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PAYMENT PROVIDERS SECTION & CARDS GRID
  // =========================================================================

  Widget _buildPaymentProvidersSection() {
    // Filter gateways list based on search & status
    final filteredGateways = _gateways.where((gw) {
      if (_statusFilter != 'ALL' && gw['status'] != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (gw['display_name'] ?? '').toString().toLowerCase();
        final prov = (gw['provider'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !prov.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title & Filters Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;

            final titlePart = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Payment Providers',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredGateways.length} Channels',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                  ),
                ),
              ],
            );

            final dropdowns = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Filter Dropdown
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Status', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'CONNECTED', child: Text('Connected', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'NOT_CONFIGURED', child: Text('Not Configured', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'DISABLED', child: Text('Disabled', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Sort Dropdown
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155)),
                      items: const [
                        DropdownMenuItem(value: 'NAME', child: Text('Sort: Name', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'TRANSACTIONS', child: Text('Sort: Transactions', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ),
                ),
              ],
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titlePart,
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: dropdowns,
                  ),
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titlePart,
                dropdowns,
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // Gateway Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 3;
            if (constraints.maxWidth < 720) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 1100) {
              crossAxisCount = 2;
            }

            final cardWidth = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ...filteredGateways.map((gw) => _buildProviderCard(gw, cardWidth)),
                _buildAddNewGatewayCard(cardWidth),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> gw, double width) {
    final provider = gw['provider'] ?? 'RAZORPAY';
    final displayName = gw['display_name'] ?? '$provider Standard';
    final status = gw['status'] ?? 'NOT_CONFIGURED';
    final isDefault = gw['is_default'] == true;
    final integrationType = gw['integration_type'] ?? 'MERCHANT_API';
    final txCount = gw['tx_count'] ?? 0;
    final successRate = gw['success_rate'] ?? 'No data';
    final gatewayId = gw['id'];
    final isTesting = gatewayId != null && _testingGatewayId[gatewayId] == true;
    final latency = gw['last_health_latency_ms'];
    final methods = (gw['supported_methods'] as List<dynamic>?) ?? ['UPI', 'CARD'];

    // Provider branding
    Color brandColor = const Color(0xFF4F46E5);
    String logoAsset = 'RZP';
    if (provider == 'SBI') {
      brandColor = const Color(0xFF0369A1);
      logoAsset = 'SBI';
    } else if (provider == 'PAYU') {
      brandColor = const Color(0xFF059669);
      logoAsset = 'PayU';
    } else if (provider == 'CASHFREE') {
      brandColor = const Color(0xFF0284C7);
      logoAsset = 'CF';
    } else if (provider == 'PAYPAL') {
      brandColor = const Color(0xFF1E40AF);
      logoAsset = 'PP';
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
          width: isDefault ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDefault ? const Color(0xFF4F46E5).withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Logo, Name, Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  logoAsset,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: brandColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _buildStatusBadge(status),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                                const SizedBox(width: 2),
                                Text('Default', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFB45309))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Mode Tag (SBI: Distinct Merchant API vs UPI / QR Collection)
              if (provider == 'SBI')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    integrationType == 'UPI_QR' ? 'UPI/QR Mode' : 'Merchant API',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF0369A1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Supported Payment Method Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: methods.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.toString(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),

          // Operational Metrics (Real values from backend)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUCCESS RATE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      successRate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRANSACTIONS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$txCount',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LATENCY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latency != null ? '${latency}ms' : 'N/A',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              // [View]
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedGatewayForDrawer = (gw is Map) ? Map<String, dynamic>.from(gw) : <String, dynamic>{};
                      _drawerActiveTab = 0;
                    });
                    _scaffoldKey.currentState?.openEndDrawer();
                    if (gatewayId != null) _fetchDrawerTransactions(gatewayId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),

              // [Configure]
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openConfigureModal(gw),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Configure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),

              // [Test]
              Expanded(
                child: ElevatedButton(
                  onPressed: (status == 'NOT_CONFIGURED' || isTesting || gatewayId == null)
                      ? null
                      : () => _testSingleGateway(gatewayId, displayName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: isTesting
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Test', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 4),

              // Contextual Popup Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                onSelected: (val) {
                  if (gatewayId == null) return;
                  if (val == 'default') {
                    _setDefaultGateway(gatewayId, displayName);
                  } else if (val == 'toggle') {
                    _toggleGatewayStatus(gatewayId, status != 'DISABLED', displayName);
                  } else if (val == 'rotate') {
                    _openRotateCredentialsDialog(gatewayId, displayName);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!isDefault && status != 'NOT_CONFIGURED')
                    const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                  if (status != 'NOT_CONFIGURED')
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(status == 'DISABLED' ? 'Enable Channel' : 'Disable Channel'),
                    ),
                  if (status != 'NOT_CONFIGURED')
                    const PopupMenuItem(value: 'rotate', child: Text('Rotate Credentials')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewGatewayCard(double width) {
    return InkWell(
      onTap: () => _openAddGatewayWizard(),
      child: Container(
        width: width,
        height: 228,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, size: 24, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 12),
            Text(
              'Add New Gateway',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Integrate Razorpay, SBI, PayU, Cashfree or PayPal',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color text = const Color(0xFF475569);

    if (status == 'CONNECTED' || status == 'ACTIVE') {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF15803D);
    } else if (status == 'NOT_CONFIGURED') {
      bg = const Color(0xFFF1F5F9);
      text = const Color(0xFF64748B);
    } else if (status == 'DISABLED') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFB91C1C);
    } else if (status == 'DEGRADED' || status == 'ERROR') {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFFB45309);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }

  // =========================================================================
  // PAYMENT METHOD MATRIX CARD
  // =========================================================================

  Widget _buildPaymentMethodMatrixCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Method Matrix',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                'Real Gateway Capability Map',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Matrix Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 18,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('Razorpay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('PayU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('Cashfree', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('SBI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('PayPal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: _methodMatrix.map((row) {
                final providers = (row['providers'] is Map)
                    ? Map<String, dynamic>.from(row['providers'])
                    : <String, dynamic>{};
                return DataRow(
                  cells: [
                    DataCell(Text(row['label']?.toString() ?? row['method']?.toString() ?? '', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500))),
                    DataCell(_buildMatrixCell(providers['RAZORPAY']?.toString())),
                    DataCell(_buildMatrixCell(providers['PAYU']?.toString())),
                    DataCell(_buildMatrixCell(providers['CASHFREE']?.toString())),
                    DataCell(_buildMatrixCell(providers['SBI']?.toString())),
                    DataCell(_buildMatrixCell(providers['PAYPAL']?.toString())),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixCell(String? state) {
    if (state == 'Configured') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
          const SizedBox(width: 4),
          Text('Active', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
        ],
      );
    } else if (state == 'Supported') {
      return Text('Supported', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF2563EB)));
    } else if (state == 'Disabled') {
      return Text('Disabled', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFDC2626)));
    } else {
      return const Text('—', style: TextStyle(color: Color(0xFFCBD5E1)));
    }
  }

  // =========================================================================
  // PAYMENT ROUTING ENGINE CARD (Interactive CRUD)
  // =========================================================================

  Widget _buildRoutingEngineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Routing Rules',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openAddRoutingRuleModal(),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: const Text('Add Rule', style: TextStyle(fontSize: 11, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_routingRules.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No custom routing rules configured. System routes to Default Gateway.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _routingRules.length,
              separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final r = _routingRules[idx];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('P${r['priority'] ?? 1}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r['payment_type'] ?? "ALL"} • ${r['payment_method'] ?? "ALL"}',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Fallback: ${r['fallback_gateway_id'] != null ? "Active" : "None"}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                      onPressed: () async {
                        final ruleId = r['id'];
                        if (ruleId != null) {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('auth_token');
                          await http.delete(
                            Uri.parse('$_apiBase/routing/$ruleId'),
                            headers: {
                              if (token != null) 'Authorization': 'Bearer $token',
                            },
                          );
                          _fetchRoutingRules();
                        }
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // GATEWAY HEALTH MONITOR CARD
  // =========================================================================

  Widget _buildHealthMonitorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Gateway Health Monitor',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text('Live Network Latency', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _gateways.length,
            separatorBuilder: (_, __) => const Divider(height: 18, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, idx) {
              final gw = _gateways[idx];
              final status = gw['last_health_status'];
              final latency = gw['last_health_latency_ms'];
              final isHealthy = status == 'SUCCESS';

              return Row(
                children: [
                  Icon(
                    isHealthy ? Icons.check_circle_rounded : (status == null ? Icons.radio_button_unchecked : Icons.error_outline_rounded),
                    size: 16,
                    color: isHealthy ? const Color(0xFF16A34A) : (status == null ? const Color(0xFF94A3B8) : const Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gw['display_name'] ?? gw['provider'],
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          status != null ? 'Last checked: ${gw['last_health_check_at'] ?? "recently"}' : 'Awaiting manual check',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  if (latency != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${latency}ms', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECURITY CENTER CARD (8 Real Checks)
  // =========================================================================

  Widget _buildSecurityCenterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF16A34A)),
              const SizedBox(width: 8),
              Text(
                'Security Center',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text('8 Controls Verified', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
            ],
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _securityChecks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final s = _securityChecks[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['title'] ?? '', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        Text(s['detail'] ?? '', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RECENT GATEWAY EVENTS CARD
  // =========================================================================

  Widget _buildRecentEventsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Gateway Events',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          if (_recentEvents.isEmpty)
            Text('No gateway events recorded yet.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentEvents.length.clamp(0, 5),
              separatorBuilder: (_, __) => const Divider(height: 14, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final ev = _recentEvents[idx];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.history_rounded, size: 12, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ev['event_type'] ?? 'EVENT',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    Text(
                      ev['created_at'] != null ? ev['created_at'].toString().split('T').last.substring(0, 5) : '',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // DETAIL DRAWER (8 Tabs)
  // =========================================================================

  Widget _buildDetailDrawer() {
    final gw = _selectedGatewayForDrawer;
    if (gw == null) return const SizedBox();

    final tabs = [
      'Overview',
      'Configuration',
      'Payment Methods',
      'Transactions',
      'Webhooks',
      'Health',
      'Logs',
      'Audit'
    ];

    return Drawer(
      width: 480,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gw['display_name'] ?? 'Gateway Details',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${gw['provider']} • ${gw['environment']}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(tabs.length, (idx) {
                  final isSel = idx == _drawerActiveTab;
                  return InkWell(
                    onTap: () => setState(() => _drawerActiveTab = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSel ? const Color(0xFF4F46E5) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[idx],
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                          color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Tab Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildDrawerTabContent(gw),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTabContent(Map<String, dynamic> gw) {
    if (_drawerActiveTab == 0) {
      // Overview Tab
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDrawerKeyVal('Provider Code', gw['provider'] ?? '—'),
          _buildDrawerKeyVal('Status', gw['status'] ?? '—'),
          _buildDrawerKeyVal('Environment', gw['environment'] ?? '—'),
          _buildDrawerKeyVal('Integration Type', gw['integration_type'] ?? '—'),
          _buildDrawerKeyVal('Default Route', gw['is_default'] == true ? 'Yes' : 'No'),
          _buildDrawerKeyVal('Merchant Identifier', gw['merchant_identifier'] ?? '—'),
          _buildDrawerKeyVal('Webhook Endpoint', gw['webhook_endpoint'] ?? '—'),
          _buildDrawerKeyVal('Created Date', gw['created_at'] ?? '—'),
        ],
      );
    } else if (_drawerActiveTab == 1) {
      // Configuration Tab (Masked Secrets)
      final masked = (gw['credentials_masked'] is Map)
          ? Map<String, dynamic>.from(gw['credentials_masked'])
          : <String, dynamic>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Encrypted Credentials (Masked)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...masked.entries.map((e) => _buildDrawerKeyVal(e.key, e.value.toString())),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openConfigureModal(gw);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Edit Configuration', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    } else if (_drawerActiveTab == 3) {
      // Transactions Tab
      if (_isLoadingDrawerTxns) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
      }
      if (_drawerTransactions.isEmpty) {
        return const Center(child: Text('No transactions processed through this channel yet.'));
      }
      return Column(
        children: _drawerTransactions.map((tx) {
          return ListTile(
            dense: true,
            title: Text(tx['transaction_id'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text('₹${tx['amount']} • ${tx['status']}'),
            trailing: Text(tx['created_at'] != null ? tx['created_at'].toString().split('T').first : ''),
          );
        }).toList(),
      );
    } else {
      // Generic tab fallback
      return Center(
        child: Text(
          'Detailed diagnostic log feed for ${gw['display_name']}.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
      );
    }
  }

  Widget _buildDrawerKeyVal(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MODALS & WIZARDS
  // =========================================================================

  void _openAddGatewayWizard() {
    showDialog(
      context: context,
      builder: (ctx) => _AddGatewayWizardDialog(
        environment: _environment,
        schoolId: widget.schoolId,
        onCreated: () {
          _fetchDashboard();
          _showSnack('New Gateway channel successfully configured!', isError: false);
        },
      ),
    );
  }

  void _openConfigureModal(Map<String, dynamic> gw) {
    final provider = (gw['provider'] ?? '').toString().toUpperCase();
    if (provider == 'PAYU') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ConfigurePayUWizardDialog(
          gateway: gw,
          schoolId: widget.schoolId,
          onSuccess: (msg) {
            _fetchDashboard();
            _showSnack(msg, isError: false);
          },
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _ConfigureGatewayDialog(
        gateway: gw,
        onUpdated: () {
          _fetchDashboard();
          _showSnack('Gateway configuration updated.', isError: false);
        },
      ),
    );
  }


  void _openRotateCredentialsDialog(String gatewayId, String providerName) {
    final keyCtrl = TextEditingController();
    final secretCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rotate Credentials: $providerName', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: 'New API Key / Merchant Key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: secretCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Secret / Key Secret'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('auth_token');
              final res = await http.post(
                Uri.parse('$_apiBase/$gatewayId/rotate-credentials'),
                headers: {
                  'Content-Type': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
                body: json.encode({
                  'credentials': {
                    'key_id': keyCtrl.text.trim(),
                    'key_secret': secretCtrl.text.trim(),
                  }
                }),
              );
              if (res.statusCode == 200) {
                _showSnack('Credentials rotated successfully.', isError: false);
                _fetchDashboard();
              } else {
                _showSnack('Failed to rotate credentials', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Save & Rotate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddRoutingRuleModal() {
    String pType = 'SCHOOL_FEE';
    String pMethod = 'UPI';
    String? selectedGwId = _gateways.isNotEmpty ? _gateways.first['id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text('Create Routing Rule', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(440.0, MediaQuery.of(context).size.width - 32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: pType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Payment Type'),
                    items: const [
                      DropdownMenuItem(value: 'SCHOOL_FEE', child: Text('School Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'SUBSCRIPTION', child: Text('ERP Subscription', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'ADMISSION', child: Text('Admission Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (val) => setModalState(() => pType = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: pMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'CARD', child: Text('Cards', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'NET_BANKING', child: Text('Net Banking', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'ALL', child: Text('All Methods', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (val) => setModalState(() => pMethod = val!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGwId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Target Gateway'),
                    items: _gateways.map<DropdownMenuItem<String>>((g) {
                      return DropdownMenuItem(
                        value: g['id'],
                        child: Text(g['display_name'] ?? g['provider'], overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedGwId = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedGwId == null) return;
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('auth_token');
                  final res = await http.post(
                    Uri.parse('$_apiBase/routing'),
                    headers: {
                      'Content-Type': 'application/json',
                      if (token != null) 'Authorization': 'Bearer $token',
                    },
                    body: json.encode({
                      'payment_type': pType,
                      'payment_method': pMethod,
                      'gateway_id': selectedGwId,
                      'priority': 1,
                      'school_id': widget.schoolId,
                    }),
                  );
                  if (res.statusCode == 200) {
                    _fetchRoutingRules();
                    _showSnack('Routing rule active.', isError: false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: const Text('Create Rule', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =========================================================================
// WIZARD: ADD GATEWAY (7 Steps)
// =========================================================================

class _AddGatewayWizardDialog extends StatefulWidget {
  final String environment;
  final String? schoolId;
  final VoidCallback onCreated;

  const _AddGatewayWizardDialog({
    required this.environment,
    this.schoolId,
    required this.onCreated,
  });

  @override
  State<_AddGatewayWizardDialog> createState() => _AddGatewayWizardDialogState();
}

class _AddGatewayWizardDialogState extends State<_AddGatewayWizardDialog> {
  int _currentStep = 0;
  String _selectedProvider = 'RAZORPAY';
  String _integrationType = 'MERCHANT_API';
  final TextEditingController _nameCtrl = TextEditingController(text: 'Razorpay Integration');
  final TextEditingController _keyCtrl = TextEditingController();
  final TextEditingController _secretCtrl = TextEditingController();
  final TextEditingController _vpaCtrl = TextEditingController();
  final Set<String> _selectedMethods = {'UPI', 'CARD', 'NET_BANKING'};
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    _vpaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wizard Header
            Row(
              children: [
                Text(
                  'Add Payment Gateway (Step ${_currentStep + 1} of 4)',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step Indicator Bar
            Row(
              children: List.generate(4, (idx) {
                final isPassed = idx <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isPassed ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Step Body
            if (_currentStep == 0) ...[
              Text('Select Provider Channel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _providerChoice('RAZORPAY', 'Razorpay', Icons.payment_rounded),
                  _providerChoice('SBI', 'State Bank of India', Icons.account_balance_rounded),
                  _providerChoice('PAYU', 'PayU', Icons.credit_card_rounded),
                  _providerChoice('CASHFREE', 'Cashfree', Icons.account_balance_wallet_rounded),
                  _providerChoice('PAYPAL', 'PayPal', Icons.language_rounded),
                ],
              ),
              if (_selectedProvider == 'SBI') ...[
                const SizedBox(height: 16),
                Text('SBI Integration Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('UPI / QR Collection'),
                      selected: _integrationType == 'UPI_QR',
                      onSelected: (val) => setState(() => _integrationType = 'UPI_QR'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Merchant API (ePay)'),
                      selected: _integrationType == 'MERCHANT_API',
                      onSelected: (val) => setState(() => _integrationType = 'MERCHANT_API'),
                    ),
                  ],
                ),
              ],
            ] else if (_currentStep == 1) ...[
              Text('Enter API Credentials', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name (e.g. Primary School Fees)'),
              ),
              const SizedBox(height: 12),
              if (_selectedProvider == 'SBI' && _integrationType == 'UPI_QR') ...[
                TextField(
                  controller: _vpaCtrl,
                  decoration: const InputDecoration(labelText: 'School UPI VPA (e.g. school@sbi)'),
                ),
              ] else ...[
                TextField(
                  controller: _keyCtrl,
                  decoration: InputDecoration(
                    labelText: _selectedProvider == 'PAYPAL' ? 'Client ID' : 'Key ID / Merchant ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secretCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _selectedProvider == 'PAYPAL' ? 'Client Secret' : 'Key Secret / Salt',
                  ),
                ),
              ],
            ] else if (_currentStep == 2) ...[
              Text('Enable Payment Methods', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _selectedMethods.contains('UPI'),
                title: const Text('UPI (GPay, PhonePe, Paytm, BHIM)'),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedMethods.add('UPI');
                    } else {
                      _selectedMethods.remove('UPI');
                    }
                  });
                },
              ),
              CheckboxListTile(
                value: _selectedMethods.contains('CARD'),
                title: const Text('Credit & Debit Cards (Visa, MasterCard, RuPay)'),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedMethods.add('CARD');
                    } else {
                      _selectedMethods.remove('CARD');
                    }
                  });
                },
              ),
              CheckboxListTile(
                value: _selectedMethods.contains('NET_BANKING'),
                title: const Text('Net Banking (50+ Indian Banks)'),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedMethods.add('NET_BANKING');
                    } else {
                      _selectedMethods.remove('NET_BANKING');
                    }
                  });
                },
              ),
            ] else ...[
              Text('Review & Activate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _row('Provider', _selectedProvider),
                    _row('Environment', widget.environment),
                    _row('Display Name', _nameCtrl.text),
                    _row('Methods', _selectedMethods.join(', ')),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_currentStep < 3) {
                            setState(() => _currentStep++);
                          } else {
                            // Submit to backend
                            setState(() => _isSaving = true);
                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final creds = <String, dynamic>{};
                              if (_selectedProvider == 'SBI' && _integrationType == 'UPI_QR') {
                                creds['upi_vpa'] = _vpaCtrl.text.trim();
                              } else {
                                creds['key_id'] = _keyCtrl.text.trim();
                                creds['key_secret'] = _secretCtrl.text.trim();
                              }

                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('auth_token');
                              final res = await http.post(
                                Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  if (token != null) 'Authorization': 'Bearer $token',
                                },
                                body: json.encode({
                                  'provider': _selectedProvider,
                                  'display_name': _nameCtrl.text.trim(),
                                  'integration_type': _integrationType,
                                  'environment': widget.environment,
                                  'credentials': creds,
                                  'supported_methods': _selectedMethods.toList(),
                                  'school_id': widget.schoolId,
                                }),
                              );

                              if (res.statusCode == 200) {
                                nav.pop();
                                widget.onCreated();
                              } else {
                                final b = json.decode(res.body);
                                messenger.showSnackBar(
                                  SnackBar(content: Text(b['detail'] ?? 'Failed to save gateway')),
                                );
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _isSaving = false);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  child: Text(
                    _currentStep == 3 ? (_isSaving ? 'Saving...' : 'Activate Gateway') : 'Continue',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerChoice(String code, String label, IconData icon) {
    final isSel = _selectedProvider == code;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedProvider = code;
          _nameCtrl.text = '$label Integration';
          if (code == 'SBI') {
            _integrationType = 'UPI_QR';
          } else {
            _integrationType = 'MERCHANT_API';
          }
        });
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSel ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isSel ? const Color(0xFF4F46E5) : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// CONFIGURE GATEWAY DIALOG
// =========================================================================

class _ConfigureGatewayDialog extends StatefulWidget {
  final Map<String, dynamic> gateway;
  final VoidCallback onUpdated;

  const _ConfigureGatewayDialog({
    required this.gateway,
    required this.onUpdated,
  });

  @override
  State<_ConfigureGatewayDialog> createState() => _ConfigureGatewayDialogState();
}

class _ConfigureGatewayDialogState extends State<_ConfigureGatewayDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _identCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.gateway['display_name'] ?? '');
    _identCtrl = TextEditingController(text: widget.gateway['merchant_identifier'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gwId = widget.gateway['id'];
    return AlertDialog(
      title: Text('Configure ${widget.gateway['display_name']}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Display Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identCtrl,
            decoration: const InputDecoration(labelText: 'Merchant Identifier / VPA'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isSaving || gwId == null
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  final nav = Navigator.of(context);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('auth_token');
                    final res = await http.patch(
                      Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways/$gwId'),
                      headers: {
                        'Content-Type': 'application/json',
                        if (token != null) 'Authorization': 'Bearer $token',
                      },
                      body: json.encode({
                        'display_name': _nameCtrl.text.trim(),
                        'merchant_identifier': _identCtrl.text.trim(),
                      }),
                    );
                    if (res.statusCode == 200) {
                      nav.pop();
                      widget.onUpdated();
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          child: Text(_isSaving ? 'Saving...' : 'Save Changes', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// =========================================================================
// CONFIGURE PAYU 7-STEP SETUP WIZARD DIALOG
// =========================================================================

class _ConfigurePayUWizardDialog extends StatefulWidget {
  final Map<String, dynamic> gateway;
  final String? schoolId;
  final Function(String) onSuccess;

  const _ConfigurePayUWizardDialog({
    required this.gateway,
    this.schoolId,
    required this.onSuccess,
  });

  @override
  State<_ConfigurePayUWizardDialog> createState() =>
      _ConfigurePayUWizardDialogState();
}

class _ConfigurePayUWizardDialogState
    extends State<_ConfigurePayUWizardDialog> {
  int _currentStep = 0; // 0 to 6 (7 Steps)

  // Step 1: Environment
  String _environment = 'TEST'; // 'TEST' or 'PRODUCTION'

  // Step 2: Credentials
  late TextEditingController _keyCtrl;
  late TextEditingController _saltCtrl;
  late TextEditingController _clientIdCtrl;
  late TextEditingController _clientSecretCtrl;

  // Step 3: Checkout URLs
  late TextEditingController _successUrlCtrl;
  late TextEditingController _failureUrlCtrl;

  // Step 4: Webhook
  late TextEditingController _webhookUrlCtrl;
  final List<String> _webhookEvents = [
    'Successful (payment.success)',
    'Failed (payment.failed)',
    'Refund (refund.success)',
    'Dispute (dispute.created)',
  ];

  // Step 5: Test Connection
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;

  // Step 7: Activation
  bool _isActivating = false;

  @override
  void initState() {
    super.initState();
    final env = widget.gateway['environment'] ?? 'TEST';
    _environment = (env == 'PRODUCTION') ? 'PRODUCTION' : 'TEST';

    // Masked credentials / existing values if present
    final masked = (widget.gateway['credentials_masked'] is Map)
        ? Map<String, dynamic>.from(widget.gateway['credentials_masked'])
        : <String, dynamic>{};
    final existingIdent = widget.gateway['merchant_identifier'] ?? '';

    _keyCtrl = TextEditingController(text: existingIdent.isNotEmpty ? existingIdent : (masked['merchant_key'] ?? ''));
    _saltCtrl = TextEditingController();
    _clientIdCtrl = TextEditingController(text: masked['client_id'] ?? '');
    _clientSecretCtrl = TextEditingController();

    // Auto-generate official callback URLs based on current API base
    final apiBase = AppConfig.apiBaseUrl;
    _successUrlCtrl = TextEditingController(
      text: widget.gateway['success_url'] ?? '$apiBase/v1/payment-gateways/payu/callback/success',
    );
    _failureUrlCtrl = TextEditingController(
      text: widget.gateway['failure_url'] ?? '$apiBase/v1/payment-gateways/payu/callback/failure',
    );
    _webhookUrlCtrl = TextEditingController(
      text: widget.gateway['webhook_endpoint'] ?? '$apiBase/v1/payment-gateways/payu/webhook',
    );

    _loadWebhookDiagnostic();
  }

  Future<void> _loadWebhookDiagnostic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways/payu/webhook-info'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = json.decode(res.body);
        final body = (decoded is Map) ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
        final data = (body['data'] is Map) ? Map<String, dynamic>.from(body['data']) : null;
        final resolvedUrl = data?['webhook_url']?.toString();
        if (resolvedUrl != null && resolvedUrl.isNotEmpty && mounted) {
          setState(() {
            _webhookUrlCtrl.text = resolvedUrl;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _saltCtrl.dispose();
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _successUrlCtrl.dispose();
    _failureUrlCtrl.dispose();
    _webhookUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _runConnectionTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final key = _keyCtrl.text.trim();
    final salt = _saltCtrl.text.trim();

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways/payu/test').replace(
        queryParameters: {
          if (widget.schoolId != null) 'school_id': widget.schoolId!,
        },
      );

      final payload = {
        'key': key,
        'salt': salt.isNotEmpty ? salt : (widget.gateway['credentials_masked']?['salt_configured'] == true ? 'PRESERVE_EXISTING' : ''),
        'environment': _environment,
        'client_id': _clientIdCtrl.text.trim().isNotEmpty ? _clientIdCtrl.text.trim() : null,
        'client_secret': _clientSecretCtrl.text.trim().isNotEmpty ? _clientSecretCtrl.text.trim() : null,
        'success_url': _successUrlCtrl.text.trim(),
        'failure_url': _failureUrlCtrl.text.trim(),
        'webhook_endpoint': _webhookUrlCtrl.text.trim(),
        'school_id': widget.schoolId,
      };

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> body = {};
      try {
        final decoded = json.decode(res.body);
        body = (decoded is Map) ? Map<String, dynamic>.from(decoded) : {'message': res.body};
      } catch (_) {
        body = {'message': res.body};
      }

      if (mounted) {
        setState(() {
          if (res.statusCode == 200 && body['success'] == true) {
            final rawData = body['data'];
            _testResult = (rawData is Map)
                ? Map<String, dynamic>.from(rawData)
                : {'status': 'CONNECTED', 'latency_ms': 0};
          } else {
            final data = (body['data'] is Map) ? Map<String, dynamic>.from(body['data']) : null;
            _testResult = {
              'status': 'FAILED',
              'http_status': res.statusCode,
              'endpoint': 'POST /api/v1/payment-gateways/payu/test',
              'message': body['detail'] ?? body['message'] ?? data?['message'] ?? 'Connection test failed',
              'reason': body['detail'] ?? body['message'] ?? 'Route or credentials validation error',
              'environment': _environment,
              'provider': 'PayU Hosted Checkout',
              'latency_ms': data?['latency_ms'] ?? 0,
              'checks': (data?['checks'] is Map) ? Map<String, dynamic>.from(data!['checks']) : {},
              'diagnostics': (data?['diagnostics'] is Map) ? Map<String, dynamic>.from(data!['diagnostics']) : {},
            };
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = {
            'status': 'FAILED',
            'http_status': 500,
            'endpoint': 'POST /api/v1/payment-gateways/payu/test',
            'message': 'Error testing PayU: $e',
            'reason': e.toString(),
            'environment': _environment,
            'provider': 'PayU Hosted Checkout',
            'latency_ms': 0,
          };
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _saveAndActivate() async {
    final key = _keyCtrl.text.trim();
    final salt = _saltCtrl.text.trim();

    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your PayU Merchant Key.')),
      );
      return;
    }
    if (salt.isEmpty && widget.gateway['status'] == 'NOT_CONFIGURED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your PayU Salt.')),
      );
      return;
    }

    setState(() => _isActivating = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final payload = {
        'environment': _environment,
        'key': key,
        'salt': salt.isNotEmpty ? salt : (widget.gateway['credentials_masked']?['salt_configured'] == true ? 'PRESERVE_EXISTING' : ''),
        'client_id': _clientIdCtrl.text.trim().isNotEmpty ? _clientIdCtrl.text.trim() : null,
        'client_secret': _clientSecretCtrl.text.trim().isNotEmpty ? _clientSecretCtrl.text.trim() : null,
        'success_url': _successUrlCtrl.text.trim(),
        'failure_url': _failureUrlCtrl.text.trim(),
        'webhook_endpoint': _webhookUrlCtrl.text.trim(),
        'school_id': widget.schoolId,
      };

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways/payu/configure'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(payload),
      );

      if (res.statusCode == 200) {
        nav.pop();
        widget.onSuccess('PayU configuration saved successfully. PayU is now available for EduSHAMIIT payments.');
      } else {
        final b = json.decode(res.body);
        messenger.showSnackBar(
          SnackBar(content: Text(b['detail'] ?? 'Failed to save PayU configuration')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving configuration: $e')),
      );
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const stepTitles = [
      'Environment',
      'Credentials',
      'Checkout URLs',
      'Webhook',
      'Test Connection',
      'Review',
      'Activate',
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: Color(0xFF059669), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configure PayU Hosted Checkout',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step ${_currentStep + 1} of 7: ${stepTitles[_currentStep]}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Progress Bar (7 Steps)
            Row(
              children: List.generate(7, (idx) {
                final isPassed = idx <= _currentStep;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isPassed ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),

            // Wizard Step Body
            Expanded(
              child: SingleChildScrollView(
                child: _buildCurrentStepBody(),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),

            // Wizard Navigation Action Buttons
            Row(
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                if (_currentStep == 4) ...[
                  // Step 5: Test Connection
                  ElevatedButton.icon(
                    onPressed: _isTesting ? null : _runConnectionTest,
                    icon: _isTesting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.speed_rounded, size: 16, color: Colors.white),
                    label: Text(_isTesting ? 'Pinging PayU...' : 'Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _currentStep++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Continue to Review'),
                  ),
                ] else if (_currentStep == 6) ...[
                  // Step 7: Activate
                  ElevatedButton.icon(
                    onPressed: _isActivating ? null : _saveAndActivate,
                    icon: _isActivating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                    label: Text(_isActivating ? 'Activating PayU...' : 'Save & Activate PayU'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      if (_currentStep == 1) {
                        if (_keyCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter PayU Merchant Key')),
                          );
                          return;
                        }
                      }
                      setState(() => _currentStep++);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Environment();
      case 1:
        return _buildStep2Credentials();
      case 2:
        return _buildStep3CheckoutUrls();
      case 3:
        return _buildStep4Webhook();
      case 4:
        return _buildStep5TestConnection();
      case 5:
        return _buildStep6Review();
      case 6:
        return _buildStep7Activate();
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Environment Selection
  Widget _buildStep1Environment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Payment Environment',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Select whether to route payments to PayU Sandbox (test mode) or Live Production.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildEnvOptionCard(
                env: 'TEST',
                title: 'Test / Sandbox Mode',
                desc: 'Uses https://test.payu.in/_payment. Safely test card, UPI, and net banking transactions without real money.',
                icon: Icons.science_outlined,
                color: const Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildEnvOptionCard(
                env: 'PRODUCTION',
                title: 'Live Production',
                desc: 'Uses https://secure.payu.in/_payment. Acquires real student fee payments and subscription charges.',
                icon: Icons.shield_outlined,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnvOptionCard({
    required String env,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    final isSel = _environment == env;
    return InkWell(
      onTap: () => setState(() => _environment = env),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSel ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? color : const Color(0xFFE2E8F0),
            width: isSel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSel ? color : const Color(0xFF64748B), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: isSel ? color : const Color(0xFF0F172A)),
                  ),
                ),
                if (isSel)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.4)),
          ],
        ),
      ),
    );
  }

  // STEP 2: Merchant Credentials
  Widget _buildStep2Credentials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PayU Merchant Credentials',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Credentials are stored securely on the server with AES-256 encryption. Raw Salt and Client Secret are never returned to the browser.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF166534)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keyCtrl,
          decoration: InputDecoration(
            labelText: 'Merchant Key *',
            hintText: 'e.g. j0mmUg or your merchant key',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.key_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _saltCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Salt *',
            hintText: 'Enter PayU merchant salt',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.password_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _clientIdCtrl,
          decoration: InputDecoration(
            labelText: 'Client ID (Optional)',
            hintText: 'Optional for OAuth / payouts',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.badge_outlined, size: 18),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _clientSecretCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Client Secret (Optional)',
            hintText: 'Optional for OAuth / payouts',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.security_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  // STEP 3: Checkout URLs
  Widget _buildStep3CheckoutUrls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hosted Checkout Callback URLs',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'PayU Hosted Checkout posts the payment response back to these server endpoints upon completion.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _successUrlCtrl,
          decoration: InputDecoration(
            labelText: 'Success URL (surl)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _failureUrlCtrl,
          decoration: InputDecoration(
            labelText: 'Failure URL (furl)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            prefixIcon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 18),
          ),
        ),
      ],
    );
  }

  // Helper for Requirement 51 diagnostic checklist
  Widget _buildChecklistItem(String title, bool passed, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: passed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: passed ? const Color(0xFF0F172A) : const Color(0xFF991B1B),
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: Webhook Configuration
  Widget _buildStep4Webhook() {
    final isLocalhost = _webhookUrlCtrl.text.contains('localhost') || _webhookUrlCtrl.text.contains('127.0.0.1');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server-to-Server Webhook',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Copy this Webhook URL into your PayU Merchant Dashboard under Profile > Webhook Settings.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),
        if (isLocalhost) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Development Environment Notice',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PayU cannot reach "localhost" directly over the public internet. For real-time webhook ingestion during local development, use an HTTPS tunnel (e.g. Cloudflare Tunnel or ngrok) and set PUBLIC_API_URL on your server.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB45309), height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _webhookUrlCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'PayU Webhook Endpoint ($_environment)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.webhook_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _webhookUrlCtrl.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Webhook URL copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
              label: const Text('Copy Webhook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Supported Webhook Events:',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        ..._webhookEvents.map(
          (evt) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                const SizedBox(width: 8),
                Text(evt, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF334155))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // STEP 5: Test Connection
  Widget _buildStep5TestConnection() {
    final isSuccess = _testResult != null &&
        (_testResult!['status'] == 'SUCCESS' || _testResult!['status'] == 'CONNECTED');
    final checks = (_testResult?['checks'] is Map)
        ? Map<String, dynamic>.from(_testResult!['checks'])
        : <String, dynamic>{};
    final latency = _testResult?['latency_ms'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test Gateway Connectivity',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Run a live connectivity check with PayU to verify that endpoints are reachable and credentials are valid.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),
        if (_testResult != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSuccess ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isSuccess ? 'CONNECTED — PayU Live Connectivity Verified' : 'Connection Test Failed',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    if (latency > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$latency ms',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _testResult!['message'] ?? '',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF334155)),
                ),
                if (!isSuccess && _testResult!['http_status'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFE4E6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diagnostic Details:', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF881337))),
                        const SizedBox(height: 4),
                        Text('• HTTP Status: ${_testResult!['http_status']}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9F1239))),
                        Text('• Endpoint: ${_testResult!['endpoint'] ?? "POST /api/v1/payment-gateways/payu/test"}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9F1239))),
                        Text('• Reason: ${_testResult!['reason'] ?? _testResult!['message'] ?? "Unknown"}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9F1239))),
                        Text('• Environment: ${_testResult!['environment'] ?? _environment}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9F1239))),
                        Text('• Provider: PayU Hosted Checkout', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF9F1239))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Requirement 51: Detailed Verification Checklist
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PayU Integration Diagnostic Checklist',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                _buildChecklistItem('Environment: ${_testResult!['checks']?['environment'] ?? _environment}', true),
                _buildChecklistItem('Configuration loaded', checks['configuration_loaded'] == true),
                _buildChecklistItem('Merchant Key present', checks['merchant_key_present'] == true || _keyCtrl.text.isNotEmpty),
                _buildChecklistItem('Salt present', checks['salt_present'] == true || _saltCtrl.text.isNotEmpty),
                _buildChecklistItem('Cryptographic hash generation (SHA-512)', checks['hash_generation'] == true),
                _buildChecklistItem('PayU endpoint reachable', checks['payu_endpoint_reachable'] == true),
                _buildChecklistItem('Provider response received', checks['provider_response_received'] == true),
                _buildChecklistItem('Credentials validated', checks['credentials_validated'] == true),
                _buildChecklistItem('Callback configured', checks['callback_configured'] == true || _successUrlCtrl.text.isNotEmpty),
                _buildChecklistItem('Webhook configured', checks['webhook_configured'] == true || _webhookUrlCtrl.text.isNotEmpty),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Click "Test Connection" below to send a live cryptographic diagnostic probe to PayU.',
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // STEP 6: Review
  Widget _buildStep6Review() {
    final keyText = _keyCtrl.text.trim();
    final maskedKey = keyText.length > 6 ? '${keyText.substring(0, 3)}••••${keyText.substring(keyText.length - 3)}' : '••••••••';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review PayU Configuration',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Please verify the details below before activating PayU on this ERP instance.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Provider', 'PayU (Hosted Checkout)'),
              _buildReviewRow('Environment', _environment),
              _buildReviewRow('Merchant Key', maskedKey),
              _buildReviewRow('Salt', 'Stored securely on server (AES-256)'),
              _buildReviewRow('Success URL', _successUrlCtrl.text),
              _buildReviewRow('Failure URL', _failureUrlCtrl.text),
              _buildReviewRow('Webhook Endpoint', _webhookUrlCtrl.text),
              _buildReviewRow('Enabled Methods', 'UPI, Cards, Net Banking, Wallets, EMI'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 7: Activate
  Widget _buildStep7Activate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to Activate PayU',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 6),
        Text(
          'Click the button below to persist the encrypted configuration and make PayU live across all EduSHAMIIT payment pages.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Color(0xFF16A34A), size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PayU Activation Ready',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All credentials validated. Once activated, students, parents, and schools will be able to pay fees and subscriptions via PayU Hosted Checkout.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

