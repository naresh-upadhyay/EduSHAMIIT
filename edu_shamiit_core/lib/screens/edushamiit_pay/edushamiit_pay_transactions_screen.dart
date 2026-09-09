import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'edushamiit_pay_transaction_drawer.dart';

class EduSHAMIITPayTransactionsScreen extends StatefulWidget {
  final String? schoolId;

  const EduSHAMIITPayTransactionsScreen({super.key, this.schoolId});

  @override
  State<EduSHAMIITPayTransactionsScreen> createState() => _EduSHAMIITPayTransactionsScreenState();
}

class _EduSHAMIITPayTransactionsScreenState extends State<EduSHAMIITPayTransactionsScreen> {
  bool _isLoading = false;
  List<dynamic> _transactions = [];
  String _selectedStatus = 'ALL';
  String _selectedEcosystem = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _selectedTransaction;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      var urlStr = '${AppConfig.apiBaseUrl}/v1/edushamiit-pay/admin/transactions?limit=100';
      if (_selectedStatus != 'ALL') urlStr += '&status=$_selectedStatus';
      if (_selectedEcosystem != 'ALL') urlStr += '&ecosystem=$_selectedEcosystem';

      final res = await http.get(Uri.parse(urlStr));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        setState(() {
          _transactions = body['data']['transactions'] ?? [];
        });
      } else {
        setState(() {
          _transactions = [];
        });
      }
    } catch (_) {
      setState(() {
        _transactions = [];
      });
    }
    setState(() => _isLoading = false);
  }

  void _openTransactionDrawer(Map<String, dynamic> txn) {
    setState(() => _selectedTransaction = txn);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _transactions.where((t) {
      final q = _searchCtrl.text.toLowerCase();
      if (q.isNotEmpty) {
        final name = (t['customer_name'] ?? '').toString().toLowerCase();
        final ref = (t['transaction_id'] ?? '').toString().toLowerCase();
        final purpose = (t['purpose'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !ref.contains(q) && !purpose.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Fee Transactions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exporting transactions to CSV report...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchTransactions,
          ),
          const SizedBox(width: 12),
        ],
      ),
      endDrawer: _selectedTransaction != null
          ? EduSHAMIITPayTransactionDrawer(
              transaction: _selectedTransaction!,
              onRefresh: _fetchTransactions,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Filter bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search by student name, invoice, transaction ID...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'SUCCESS', child: Text('Success')),
                      DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                      DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedStatus = v);
                        _fetchTransactions();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedEcosystem,
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Ecosystems')),
                      DropdownMenuItem(value: 'SCHOOL_FEE', child: Text('School Fee')),
                      DropdownMenuItem(value: 'SUBSCRIPTION', child: Text('Subscription')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedEcosystem = v);
                        _fetchTransactions();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          showCheckboxColumn: false,
                          columns: const [
                            DataColumn(label: Text('Transaction Ref')),
                            DataColumn(label: Text('Student Name')),
                            DataColumn(label: Text('Purpose')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Settlement')),
                            DataColumn(label: Text('Action')),
                          ],
                          rows: filtered.map((t) {
                            final isSuccess = t['status'] == 'SUCCESS';
                            return DataRow(
                              onSelectChanged: (_) => _openTransactionDrawer(t),
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
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                                    onPressed: () => _openTransactionDrawer(t),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
