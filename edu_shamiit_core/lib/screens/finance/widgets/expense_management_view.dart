import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_api_service.dart';
import '../models/finance_models.dart';

class ExpenseManagementView extends ConsumerStatefulWidget {
  const ExpenseManagementView({super.key});

  @override
  ConsumerState<ExpenseManagementView> createState() => _ExpenseManagementViewState();
}

class _ExpenseManagementViewState extends ConsumerState<ExpenseManagementView> {
  final _api = FinanceApiService();
  List<ExpenseModel> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final data = await _api.getExpenses();
    setState(() {
      _expenses = data;
      _isLoading = false;
    });
  }

  void _openAddExpenseModal() {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record New Expense'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: min(450.0, MediaQuery.of(ctx).size.width - 32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Expense Title (e.g. Electricity Bill)')),
                const SizedBox(height: 12),
                TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (titleCtrl.text.isNotEmpty && amt > 0) {
                await _api.createExpense({
                  'category_name': 'Utilities',
                  'title': titleCtrl.text.trim(),
                  'amount': amt,
                  'expense_date': '2026-09-01',
                  'payment_mode': 'BANK_TRANSFER',
                });
                if (mounted) Navigator.pop(ctx);
                _loadExpenses();
              }
            },
            child: const Text('Submit Expense'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 620;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Management & Approvals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track operational expenses, vendor purchases, utility bills, and approval flows.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openAddExpenseModal,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expense Management & Approvals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track operational expenses, vendor purchases, utility bills, and approval flows.',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _openAddExpenseModal,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        if (_isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('No expenses recorded yet. Click "Add Expense" to record utility bills or purchases.')),
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
                  DataColumn(label: Text('Expense #', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _expenses.map((exp) {
                  return DataRow(cells: [
                    DataCell(Text(exp.expenseNumber, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(exp.title)),
                    DataCell(Text(exp.expenseDate)),
                    DataCell(Text('₹${exp.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(exp.paymentMode)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(exp.status, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
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
