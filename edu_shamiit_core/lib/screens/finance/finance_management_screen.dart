import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/finance_provider.dart';
import 'fees_management_tab.dart';

class FinanceManagementScreen extends ConsumerWidget {
  const FinanceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finance Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  'Monitor collections, expenses, receivables and institutional financial health',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Financial Year Selector
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.financialYear,
                items: const [
                  DropdownMenuItem(value: '2026-27', child: Text('Financial Year 2026-27', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: '2025-26', child: Text('Financial Year 2025-26', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {},
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Financial Data',
            onPressed: () => notifier.loadAll(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: const FeesManagementTab(),
    );
  }
}
