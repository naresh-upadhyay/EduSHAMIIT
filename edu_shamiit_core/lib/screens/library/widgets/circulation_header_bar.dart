import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import '../providers/circulation_provider.dart';
import 'dialogs/quick_issue_dialog.dart';
import 'dialogs/quick_return_dialog.dart';
import 'dialogs/requests_management_dialog.dart';
import 'dialogs/fine_collection_dialog.dart';
import 'dialogs/renew_book_dialog.dart';

class CirculationHeaderBar extends ConsumerWidget {
  const CirculationHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleState = ref.watch(roleProvider);
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Title & Subtitle (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  !isLibraryAdmin ? 'My Issue / Return Loans' : 'Issue / Return',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !isLibraryAdmin
                      ? 'View books issued to you, your renewal requests, and return history. Physical returns must be submitted directly at the library counter.'
                      : 'Issue, return, renew books and manage all library transactions.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 2. Action Buttons (Right)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!isLibraryAdmin) ...[
                // Info banner for returning books
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF6366F1)),
                      SizedBox(width: 6),
                      Text(
                        'Physical Returns at Library Desk',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                ),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'Refresh Transactions',
                  onPressed: () {
                    notifier.fetchStats();
                    notifier.fetchTransactions(resetPage: true);
                  },
                ),
              ] else ...[
                // + Issue Book (Primary Purple Button)
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Issue Book', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const QuickIssueDialog(),
                    );
                  },
                ),

                // Return Book (Outlined Button)
                OutlinedButton.icon(
                  icon: const Icon(Icons.keyboard_return_rounded, size: 17),
                  label: const Text('Return Book', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const QuickReturnDialog(),
                    );
                  },
                ),

                // More Actions Dropdown Menu
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.more_horiz_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF334155)),
                        const SizedBox(width: 6),
                        Text('More Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155))),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    if (val == 'requests') {
                      showDialog(context: context, builder: (_) => const RequestsManagementDialog());
                    } else if (val == 'fines') {
                      showDialog(context: context, builder: (_) => const FineCollectionDialog());
                    } else if (val == 'renew') {
                      showDialog(context: context, builder: (_) => const RenewBookDialog());
                    } else if (val == 'refresh') {
                      notifier.fetchStats();
                      notifier.fetchActivities();
                      notifier.fetchOverdueSummary();
                      notifier.fetchTransactions(resetPage: true);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'requests',
                      child: Row(
                        children: [
                          Icon(Icons.assignment_outlined, size: 18, color: Color(0xFF6366F1)),
                          SizedBox(width: 10),
                          Text('Pending Requests'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'fines',
                      child: Row(
                        children: [
                          Icon(Icons.currency_rupee_rounded, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Text('Fine Collection'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'renew',
                      child: Row(
                        children: [
                          Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 10),
                          Text('Renew Book Loan'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                          SizedBox(width: 10),
                          Text('Refresh Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
