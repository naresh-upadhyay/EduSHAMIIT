import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_api_service.dart';
import '../models/finance_models.dart';

class PayrollManagementView extends ConsumerStatefulWidget {
  const PayrollManagementView({super.key});

  @override
  ConsumerState<PayrollManagementView> createState() => _PayrollManagementViewState();
}

class _PayrollManagementViewState extends ConsumerState<PayrollManagementView> {
  final _api = FinanceApiService();
  List<StaffPayslip> _payslips = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    setState(() => _isLoading = true);
    final data = await _api.getPayslips();
    setState(() {
      _payslips = data;
      _isLoading = false;
    });
  }

  Future<void> _runMonthlyPayroll() async {
    setState(() => _isProcessing = true);
    final ok = await _api.processPayroll('2026-08');
    setState(() => _isProcessing = false);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monthly payroll processed & payslips generated successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
      _loadPayrollData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Bar & Month Title
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Payroll & Salary Processing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage staff salary structures, monthly payroll runs, allowances and net disbursements.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _runMonthlyPayroll,
                icon: _isProcessing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_isProcessing ? 'Processing...' : 'Run August Payroll'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Payslips Data Table
        if (_isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_payslips.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('No payroll runs processed yet. Click "Run August Payroll" to generate staff payslips.'),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('Payslip #', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Basic', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Allowances', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Deductions', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _payslips.map((ps) {
                  return DataRow(cells: [
                    DataCell(Text(ps.payslipNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(ps.staffName)),
                    DataCell(Text(ps.staffRole)),
                    DataCell(Text('₹${ps.basicSalary.toStringAsFixed(0)}')),
                    DataCell(Text('₹${ps.allowances.toStringAsFixed(0)}')),
                    DataCell(Text('₹${ps.deductions.toStringAsFixed(0)}')),
                    DataCell(Text('₹${ps.netPayable.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PAID', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
