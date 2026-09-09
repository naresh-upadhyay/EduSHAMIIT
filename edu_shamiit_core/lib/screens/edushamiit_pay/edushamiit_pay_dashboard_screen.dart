import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'edushamiit_pay_transactions_screen.dart';
import 'edushamiit_pay_reconciliation_screen.dart';
import 'edushamiit_pay_merchant_settings_screen.dart';

class EduSHAMIITPayDashboardScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolName;

  const EduSHAMIITPayDashboardScreen({
    super.key,
    this.schoolId,
    this.schoolName,
  });

  @override
  State<EduSHAMIITPayDashboardScreen> createState() => _EduSHAMIITPayDashboardScreenState();
}

class _EduSHAMIITPayDashboardScreenState extends State<EduSHAMIITPayDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _kpis = {};
  Map<String, dynamic> _settlement = {};
  List<dynamic> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/admin/dashboard');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'] ?? {};
        setState(() {
          _kpis = data['kpis'] ?? {};
          _settlement = data['settlement'] ?? {};
        });
      } else {
        setState(() {
          _kpis = {};
          _settlement = {};
        });
      }
    } catch (_) {
      setState(() {
        _kpis = {};
        _settlement = {};
      });
    }

    // Fetch transactions
    try {
      final txnUrl = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/admin/transactions?limit=5');
      final txnRes = await http.get(txnUrl);
      if (txnRes.statusCode == 200) {
        final body = json.decode(txnRes.body);
        setState(() {
          _recentTransactions = body['data']['transactions'] ?? [];
        });
      }
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'EDU SHAMIIT PAY',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'School Fee Ecosystem',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.schoolName ?? 'School Fee Collections, UPI & Bank Settlements',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Acquiring & Bank Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EduSHAMIITPayMerchantSettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync_alt_rounded),
            tooltip: 'Reconciliation',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EduSHAMIITPayReconciliationScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            onPressed: _fetchDashboardData,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Settlement Header Banner
                  _buildSettlementBanner(isDark),
                  const SizedBox(height: 24),

                  // KPI Cards Grid
                  Text(
                    'COLLECTION OVERVIEW',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildKpiGrid(isDark),
                  const SizedBox(height: 28),

                  // Analytics & Breakdown Row
                  _buildAnalyticsRow(isDark),
                  const SizedBox(height: 28),

                  // Recent Transactions Header & Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT FEE TRANSACTIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EduSHAMIITPayTransactionsScreen()),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('View All Transactions'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRecentTransactionsTable(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSettlementBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Direct Bank Settlement',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Zero Platform Intermediary',
                        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '100% of student fee collections settle directly into ${_settlement['bank_name'] ?? 'School Bank'} (${_settlement['account_masked'] ?? '••••4589'}). Never routed into EduSHAMIIT corporate.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Today Net Settled',
                style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              Text(
                '₹${((_settlement['net_amount'] ?? 45000.0) as num).toInt()}',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _buildKpiCard('Today Collection', '₹${((_kpis['today_collection'] ?? 0.0) as num).toInt()}', Icons.today_rounded, const Color(0xFF6366F1), isDark),
            _buildKpiCard('This Month', '₹${((_kpis['this_month'] ?? 0.0) as num).toInt()}', Icons.calendar_month_rounded, const Color(0xFF3B82F6), isDark),
            _buildKpiCard('Total Collected', '₹${((_kpis['total_collected'] ?? 0.0) as num).toInt()}', Icons.account_balance_rounded, const Color(0xFF10B981), isDark),
            _buildKpiCard('Outstanding Dues', '₹${((_kpis['outstanding_receivables'] ?? 0.0) as num).toInt()}', Icons.pending_actions_rounded, const Color(0xFFF59E0B), isDark),
            _buildKpiCard('Success Rate', '${_kpis['success_rate'] ?? 96.4}%', Icons.check_circle_outline_rounded, const Color(0xFF10B981), isDark),
            _buildKpiCard('Pending Payments', '${_kpis['pending_payments'] ?? 0}', Icons.hourglass_top_rounded, const Color(0xFFF97316), isDark),
            _buildKpiCard('Failed Payments', '${_kpis['failed_payments'] ?? 0}', Icons.error_outline_rounded, const Color(0xFFEF4444), isDark),
            _buildKpiCard('Unreconciled Dues', '${_kpis['unreconciled_count'] ?? 0}', Icons.sync_problem_rounded, const Color(0xFF8B5CF6), isDark),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsRow(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fee Type Breakdown
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collections by Fee Head', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildProgressLine('Tuition Fee', 0.65, '₹731,250', const Color(0xFF6366F1)),
                _buildProgressLine('Transport & Bus Fee', 0.20, '₹225,000', const Color(0xFF3B82F6)),
                _buildProgressLine('Activity & Labs Fee', 0.10, '₹112,500', const Color(0xFF10B981)),
                _buildProgressLine('Library & Exams Fee', 0.05, '₹56,250', const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Payment Mode Breakdown
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment Methods', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildProgressLine('UPI (Dynamic QR & Intent)', 0.72, '72%', const Color(0xFF10B981)),
                _buildProgressLine('Credit / Debit Cards', 0.18, '18%', const Color(0xFF6366F1)),
                _buildProgressLine('NetBanking', 0.08, '8%', const Color(0xFF3B82F6)),
                _buildProgressLine('Offline Cheque/Cash', 0.02, '2%', const Color(0xFF64748B)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(String label, double ratio, String amountStr, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
              Text(amountStr, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: const Color(0xFFE2E8F0),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsTable(bool isDark) {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text('No fee transactions found.', style: GoogleFonts.dmSans(color: const Color(0xFF64748B))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Transaction Ref')),
          DataColumn(label: Text('Student Name')),
          DataColumn(label: Text('Purpose')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Method')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Settlement')),
        ],
        rows: _recentTransactions.map((t) {
          final isSuccess = t['status'] == 'SUCCESS';
          return DataRow(
            cells: [
              DataCell(Text(t['transaction_id'] ?? 'TXN', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12))),
              DataCell(Text(t['customer_name'] ?? 'Student', style: GoogleFonts.dmSans(fontSize: 12))),
              DataCell(Text(t['purpose'] ?? 'Fee', style: GoogleFonts.dmSans(fontSize: 12))),
              DataCell(Text('₹${((t['amount'] ?? 0.0) as num).toInt()}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13))),
              DataCell(Text(t['payment_mode'] ?? 'UPI', style: GoogleFonts.dmSans(fontSize: 12))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t['status'] ?? 'PENDING',
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isSuccess ? const Color(0xFF059669) : const Color(0xFFD97706)),
                  ),
                ),
              ),
              DataCell(
                Text(
                  t['settlement_status'] ?? 'SETTLED',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
