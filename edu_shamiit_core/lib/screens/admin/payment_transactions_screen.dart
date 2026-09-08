import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/config/app_config.dart';
import 'payment_details_drawer.dart';

class PaymentTransactionsScreen extends StatefulWidget {
  final String? authToken;

  const PaymentTransactionsScreen({super.key, this.authToken});

  @override
  State<PaymentTransactionsScreen> createState() => _PaymentTransactionsScreenState();
}

class _PaymentTransactionsScreenState extends State<PaymentTransactionsScreen> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  String _selectedFilter = 'ALL';
  Map<String, dynamic>? _selectedTransaction;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final url = '${AppConfig.apiBaseUrl}/v1/payments/admin/transactions?status=$_selectedFilter';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null) 'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _transactions = body['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyTransaction(String paymentId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/$paymentId/verify'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verification processed successfully.')),
        );
        _fetchTransactions();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to verify payment with PayU.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Payment Gateway Transactions',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6366F1)),
            onPressed: _fetchTransactions,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterChips(),
                const SizedBox(height: 20),
                Expanded(child: _buildTableCard()),
              ],
            ),
          ),
          if (_selectedTransaction != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: PaymentDetailsDrawer(
                transaction: _selectedTransaction!,
                onClose: () => setState(() => _selectedTransaction = null),
                onVerify: () => _verifyTransaction(_selectedTransaction!['id']),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['ALL', 'SUCCESS', 'PENDING', 'FAILED', 'CANCELLED'];
    return Row(
      children: filters.map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(filter, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: isSelected,
            selectedColor: const Color(0xFF6366F1),
            labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B)),
            onSelected: (val) {
              if (val) {
                setState(() => _selectedFilter = filter);
                _fetchTransactions();
              }
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTableCard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text('No transactions found', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Transaction ID')),
            DataColumn(label: Text('Customer / School')),
            DataColumn(label: Text('Plan')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Provider')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: _transactions.map((txn) {
            final status = txn['status'] ?? 'PENDING';
            Color statusBg = const Color(0xFFE2E8F0);
            Color statusFg = const Color(0xFF64748B);
            if (status == 'SUCCESS') {
              statusBg = const Color(0xFFECFDF5);
              statusFg = const Color(0xFF10B981);
            } else if (status == 'FAILED') {
              statusBg = const Color(0xFFFEF2F2);
              statusFg = const Color(0xFFEF4444);
            }

            return DataRow(
              cells: [
                DataCell(Text(txn['transaction_id'] ?? '-', style: GoogleFonts.firaCode(fontSize: 12))),
                DataCell(Text(txn['customer_name'] ?? 'School', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold))),
                DataCell(Text('${txn['plan_name']} (${txn['billing_cycle']})', style: GoogleFonts.dmSans(fontSize: 12))),
                DataCell(Text('₹${txn['amount']}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
                DataCell(Text('${txn['provider']} (${txn['provider_environment']})', style: GoogleFonts.dmSans(fontSize: 11))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF6366F1)),
                    onPressed: () => setState(() => _selectedTransaction = txn),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
