import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/finance_provider.dart';
import 'widgets/finance_overview_tab.dart';
import 'widgets/revenue_management_view.dart';
import 'widgets/fees_ledger_view.dart';
import 'widgets/fee_structures_view.dart';
import 'widgets/outstanding_defaulters_view.dart';
import 'widgets/payroll_management_view.dart';
import 'widgets/expense_management_view.dart';
import 'widgets/banking_accounts_view.dart';
import 'widgets/chart_of_accounts_view.dart';
import 'widgets/financial_reports_view.dart';
import 'drawers/student_fee_account_drawer.dart';
import 'dialogs/collect_payment_dialog.dart';

class FeesManagementTab extends ConsumerStatefulWidget {
  const FeesManagementTab({super.key});

  @override
  ConsumerState<FeesManagementTab> createState() => _FeesManagementTabState();
}

class _FeesManagementTabState extends ConsumerState<FeesManagementTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(financeProvider.notifier).setActiveTab(_tabController.index);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabStr = Uri.base.queryParameters['tab'];
    if (tabStr != null) {
      final tabIdx = int.tryParse(tabStr) ?? 0;
      if (tabIdx >= 0 && tabIdx < 5 && tabIdx != _tabController.index) {
        _tabController.animateTo(tabIdx);
        ref.read(financeProvider.notifier).setActiveTab(tabIdx);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Top Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Institutional Finance Suite',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Comprehensive financial control center for fees, payroll, expenses, banking, general ledger, and audit reports.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.file_download_outlined, size: 18),
                          label: const Text('Export Report'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openCollectPaymentModal(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Collect Fees'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Navigation Tabs Bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF6366F1),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF6366F1),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Revenue'),
                    Tab(text: 'Fee Collection'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Payroll'),
                  ],
                ),
                const SizedBox(height: 20),

                // Tab Content Body
                IndexedStack(
                  index: state.activeTabIndex < 5 ? state.activeTabIndex : 0,
                  children: [
                    FinanceOverviewTab(
                      onNavigateToFees: () => _tabController.animateTo(2),
                      onCollectPayment: () => _openCollectPaymentModal(context),
                    ),
                    const RevenueManagementView(),
                    FeesLedgerView(
                      onSelectStudent: (studentId) => notifier.openStudentDrawer(studentId),
                      onCollectPayment: (item) => _openCollectPaymentModal(context, studentId: item.studentId, invoiceId: item.id),
                    ),
                    const ExpenseManagementView(),
                    const PayrollManagementView(),
                  ],
                ),
              ],
            ),
          ),
        ),


        // Right-Side Student Account Slide Drawer Overlay
        if (state.selectedStudentId != null)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: StudentFeeAccountDrawer(
              onClose: () => notifier.closeStudentDrawer(),
              onCollectPayment: () => _openCollectPaymentModal(context, studentId: state.selectedStudentId),
            ),
          ),
      ],
    );
  }

  void _openCollectPaymentModal(BuildContext context, {String? studentId, String? invoiceId}) {
    showDialog(
      context: context,
      builder: (ctx) => CollectPaymentDialog(studentId: studentId, invoiceId: invoiceId),
    );
  }
}
