import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_api_service.dart';
import '../models/finance_models.dart';

class ChartOfAccountsView extends ConsumerStatefulWidget {
  const ChartOfAccountsView({super.key});

  @override
  ConsumerState<ChartOfAccountsView> createState() => _ChartOfAccountsViewState();
}

class _ChartOfAccountsViewState extends ConsumerState<ChartOfAccountsView> {
  final _api = FinanceApiService();
  List<ChartOfAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCOA();
  }

  Future<void> _loadCOA() async {
    setState(() => _isLoading = true);
    final data = await _api.getChartOfAccounts();
    setState(() {
      _accounts = data;
      _isLoading = false;
    });
  }

  void _openPostJournalModal() {
    if (_accounts.length < 2) return;
    String drAcc = _accounts.first.id;
    String crAcc = _accounts.last.id;
    final amtCtrl = TextEditingController(text: '15000');
    final descCtrl = TextEditingController(text: 'Monthly fee collection journal entry');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Journal Entry (Debit = Credit)'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: min(450.0, MediaQuery.of(context).size.width - 32)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: drAcc,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Debit Account (DR)'),
                  items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.accountCode} - ${a.accountName}', overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (v) => drAcc = v!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: crAcc,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Credit Account (CR)'),
                  items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.accountCode} - ${a.accountName}', overflow: TextOverflow.ellipsis, maxLines: 1))).toList(),
                  onChanged: (v) => crAcc = v!,
                ),
                const SizedBox(height: 12),
                TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Narration / Description')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt > 0 && drAcc != crAcc) {
                final ok = await _api.postJournalEntry({
                  'entry_date': '2026-09-01',
                  'source_module': 'MANUAL',
                  'description': descCtrl.text,
                  'items': [
                    {'account_id': drAcc, 'debit_amount': amt, 'credit_amount': 0.0, 'narration': descCtrl.text},
                    {'account_id': crAcc, 'debit_amount': 0.0, 'credit_amount': amt, 'narration': descCtrl.text},
                  ]
                });
                if (mounted) Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Double-entry journal entry posted cleanly!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              }
            },
            child: const Text('Post Entry'),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chart of Accounts & Double-Entry Ledger',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Master financial account hierarchy for assets, liabilities, equity, revenue, and operating expenses.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openPostJournalModal,
              icon: const Icon(Icons.note_add_rounded, size: 18),
              label: const Text('Post Journal Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_isLoading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
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
                  DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _accounts.map((acc) {
                  return DataRow(cells: [
                    DataCell(Text(acc.accountCode, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(acc.accountName)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(acc.accountType, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(Text(acc.isActive ? 'Active' : 'Inactive', style: TextStyle(color: acc.isActive ? const Color(0xFF10B981) : Colors.grey))),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
