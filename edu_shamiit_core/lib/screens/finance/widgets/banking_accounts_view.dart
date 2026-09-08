import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_api_service.dart';
import '../models/finance_models.dart';

class BankingAccountsView extends ConsumerStatefulWidget {
  const BankingAccountsView({super.key});

  @override
  ConsumerState<BankingAccountsView> createState() => _BankingAccountsViewState();
}

class _BankingAccountsViewState extends ConsumerState<BankingAccountsView> {
  final _api = FinanceApiService();
  List<BankAccountModel> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final data = await _api.getBankAccounts();
    setState(() {
      _accounts = data;
      _isLoading = false;
    });
  }

  void _openTransferModal() {
    if (_accounts.length < 2) return;
    String fromId = _accounts.first.id;
    String toId = _accounts.last.id;
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Internal Fund Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: fromId,
              decoration: const InputDecoration(labelText: 'From Account'),
              items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName))).toList(),
              onChanged: (val) => fromId = val!,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: toId,
              decoration: const InputDecoration(labelText: 'To Account'),
              items: _accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.accountName))).toList(),
              onChanged: (val) => toId = val!,
            ),
            const SizedBox(height: 12),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt > 0 && fromId != toId) {
                await _api.transferBankFunds({
                  'from_account_id': fromId,
                  'to_account_id': toId,
                  'amount': amt,
                  'transfer_date': '2026-09-01',
                  'remarks': 'Internal cash office transfer',
                });
                if (mounted) Navigator.pop(ctx);
                _loadAccounts();
              }
            },
            child: const Text('Transfer Funds'),
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
                  'Banking, Cash Counters & Fund Transfers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage institutional operating bank accounts, cash office drawers, and internal transfers.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openTransferModal,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Transfer Funds'),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
            ),
            itemCount: _accounts.length,
            itemBuilder: (ctx, idx) {
              final acc = _accounts[idx];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        Text(acc.accountName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(acc.accountType, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    Text('${acc.bankName} • ${acc.accountNumber}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    Text(
                      '₹${acc.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
