import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'edushamiit_pay_fee_checkout_dialog.dart';

class StudentFeesPaymentScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String schoolId;
  final String? studentClass;
  final String? admissionNumber;

  const StudentFeesPaymentScreen({
    super.key,
    this.studentId = 'STU-001',
    this.studentName = 'Aarav Sharma',
    this.schoolId = 'SCH-001',
    this.studentClass = 'Class X - Section A',
    this.admissionNumber = 'ADM-2024-0412',
  });

  @override
  State<StudentFeesPaymentScreen> createState() => _StudentFeesPaymentScreenState();
}

class _StudentFeesPaymentScreenState extends State<StudentFeesPaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/school-fees/invoices?student_id=${widget.studentId}&school_id=${widget.schoolId}'),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        setState(() {
          _invoices = body['data']['invoices'] ?? [];
        });
      }
    } catch (_) {
      // Sample fallback invoices
      setState(() {
        _invoices = [
          {
            'id': 'INV-001',
            'invoice_number': 'FEE-2026-000125',
            'fee_head': 'Tuition Fee (Quarter 1)',
            'amount_payable': 18000.0,
            'amount_paid': 0.0,
            'amount_balance': 18000.0,
            'due_date': '2026-09-30',
            'status': 'unpaid'
          },
          {
            'id': 'INV-002',
            'invoice_number': 'FEE-2026-000126',
            'fee_head': 'Transport & Bus Fee (Sep)',
            'amount_payable': 5000.0,
            'amount_paid': 0.0,
            'amount_balance': 5000.0,
            'due_date': '2026-09-30',
            'status': 'unpaid'
          },
          {
            'id': 'INV-003',
            'invoice_number': 'FEE-2026-000127',
            'fee_head': 'Annual Lab & Activity Fee',
            'amount_payable': 2000.0,
            'amount_paid': 0.0,
            'amount_balance': 2000.0,
            'due_date': '2026-10-15',
            'status': 'unpaid'
          },
          {
            'id': 'INV-004',
            'invoice_number': 'FEE-2026-000088',
            'fee_head': 'Admission & Registration Fee',
            'amount_payable': 12000.0,
            'amount_paid': 12000.0,
            'amount_balance': 0.0,
            'due_date': '2026-04-10',
            'status': 'paid'
          },
        ];
      });
    }
    setState(() => _isLoading = false);
  }

  void _openCheckoutDialog(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EduSHAMIITPayFeeCheckoutDialog(
        schoolId: widget.schoolId,
        studentId: widget.studentId,
        studentName: widget.studentName,
        feeInvoiceId: invoice['id'],
        invoiceNumber: invoice['invoice_number'],
        feeHead: invoice['fee_head'],
        amount: (invoice['amount_balance'] ?? invoice['amount_payable'] ?? 0.0).toDouble(),
        onPaymentSuccess: _fetchInvoices,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dueInvoices = _invoices.where((i) => i['status'] != 'paid').toList();
    final paidInvoices = _invoices.where((i) => i['status'] == 'paid').toList();
    final totalDue = dueInvoices.fold<double>(0.0, (sum, i) => sum + (i['amount_balance'] ?? i['amount_payable'] ?? 0.0));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Student Fee Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchInvoices),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Profile & Dues Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.studentName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.studentClass} • Adm: ${widget.admissionNumber}',
                              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Pending Dues', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalDue.toInt()}',
                              style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF6366F1),
                    labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(text: 'Current Dues (${dueInvoices.length})'),
                      const Tab(text: 'Upcoming Fees'),
                      Tab(text: 'Payment History (${paidInvoices.length})'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tab Views
                  SizedBox(
                    height: 500,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // 1. Current Dues Tab
                        _buildInvoiceList(dueInvoices, isDueTab: true),
                        // 2. Upcoming Fees Tab
                        _buildInvoiceList([], isDueTab: false),
                        // 3. Payment History Tab
                        _buildInvoiceList(paidInvoices, isDueTab: false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInvoiceList(List<dynamic> items, {required bool isDueTab}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: const Color(0xFF10B981).withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('No dues in this section', style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final inv = items[idx];
        final isPaid = inv['status'] == 'paid';
        final balance = (inv['amount_balance'] ?? inv['amount_payable'] ?? 0.0).toDouble();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPaid ? const Color(0xFF10B981) : const Color(0xFF6366F1)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPaid ? Icons.verified_outlined : Icons.receipt_long_rounded,
                  color: isPaid ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv['fee_head'] ?? 'Fee Head', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '${inv['invoice_number']} • Due ${inv['due_date'] ?? 'On demand'}',
                      style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${balance.toInt()}',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  if (isDueTab && !isPaid)
                    ElevatedButton.icon(
                      onPressed: () => _openCheckoutDialog(inv),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: const Text('Pay Now'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'PAID',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF059669)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
