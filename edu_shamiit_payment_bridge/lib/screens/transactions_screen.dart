import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_badge.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TransactionsScreen({super.key, this.onBack});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  String? _searchQuery;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  late Future<List<TransactionItem>> _transactionsFuture;
  late Future<Map<String, int>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    setState(() {
      _transactionsFuture = ApiService().getTransactions(
        status: _selectedFilter,
        search: _searchQuery,
      );
      _summaryFuture = ApiService().getTransactionsSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Transactions',
            showBackButton: true,
            onBackPressed: widget.onBack,
            actions: [
              IconButton(
                icon: Icon(_isSearchOpen ? Icons.close : Icons.search,
                    color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearchOpen = !_isSearchOpen;
                    if (!_isSearchOpen) {
                      _searchQuery = null;
                      _searchController.clear();
                      _fetch();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () => _showFilterDialog(),
              ),
            ],
          ),
          if (_isSearchOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search student, invoice, or UTR...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = null);
                            _fetch();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val.trim());
                  _fetch();
                },
              ),
            ),
          // Horizontal Filter Chips
          FilterChipsBar(
            options: const [
              'All',
              'Successful',
              'Pending',
              'Unmatched',
              'Refunds',
            ],
            selected: _selectedFilter,
            onSelected: (val) {
              setState(() => _selectedFilter = val);
              _fetch();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _fetch(),
              child: Builder(
                builder: (ctx) {
                  final bottomSafePadding = MediaQuery.of(ctx).padding.bottom;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      6,
                      16,
                      bottomSafePadding > 0 ? bottomSafePadding + 32 : 36,
                    ),
                    child: Column(
                  children: [
                    // Top 4 Metric Summary Boxes (matching screenshot)
                    FutureBuilder<Map<String, int>>(
                      future: _summaryFuture,
                      builder: (context, snapshot) {
                        final s = snapshot.data ??
                            {'successful': 0, 'pending': 0, 'unmatched': 0, 'refunds': 0};
                        return Row(
                          children: [
                            Expanded(
                              child: TransactionSummaryBox(
                                count: '${s['successful']}',
                                label: 'Successful',
                                icon: Icons.check,
                                color: AppColors.successGreen,
                                bgColor: AppColors.successGreenBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TransactionSummaryBox(
                                count: '${s['pending']}',
                                label: 'Pending',
                                icon: Icons.schedule,
                                color: AppColors.pendingBlue,
                                bgColor: AppColors.pendingBlueBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TransactionSummaryBox(
                                count: '${s['unmatched']}',
                                label: 'Unmatched',
                                icon: Icons.priority_high,
                                color: AppColors.warningOrange,
                                bgColor: AppColors.warningOrangeBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TransactionSummaryBox(
                                count: '${s['refunds']}',
                                label: 'Refunds',
                                icon: Icons.refresh,
                                color: AppColors.refundPurple,
                                bgColor: AppColors.refundPurpleBg,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Transaction Cards List
                    FutureBuilder<List<TransactionItem>>(
                      future: _transactionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text('Offline: Could not connect to server', style: TextStyle(color: AppColors.errorRed)),
                  );
                }
                final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'No transactions found',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14),
                            ),
                          );
                        }
                        return Column(
                          children: items
                              .map((tx) => _buildTransactionCard(tx))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(TransactionItem tx) {
    Color iconBg;
    Color iconFg;
    IconData icon;

    final st = tx.paymentStatus.toUpperCase();
    if (st == 'VERIFIED_SUCCESS') {
      icon = Icons.check;
      iconBg = AppColors.successGreenBg;
      iconFg = AppColors.successGreen;
    } else if (st == 'PENDING') {
      icon = Icons.schedule;
      iconBg = AppColors.pendingBlueBg;
      iconFg = AppColors.pendingBlue;
    } else if (st == 'UNMATCHED') {
      icon = Icons.priority_high;
      iconBg = AppColors.warningOrangeBg;
      iconFg = AppColors.warningOrange;
    } else if (st.contains('REFUND')) {
      icon = Icons.sync;
      iconBg = AppColors.refundPurpleBg;
      iconFg = AppColors.refundPurple;
    } else {
      icon = Icons.help_outline;
      iconBg = AppColors.ignoredGreyBg;
      iconFg = AppColors.ignoredGrey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailsScreen(transactionId: tx.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconFg, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tx.formattedAmount,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        StatusBadge(
                          status: tx.paymentStatus,
                          customLabel: tx.paymentStatus == 'VERIFIED_SUCCESS'
                              ? 'Successful'
                              : (tx.paymentStatus == 'REFUNDED'
                                  ? 'Refunded'
                                  : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (tx.studentName != null)
                      Text(
                        '${tx.studentName} • ${tx.invoiceNumber ?? ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const Text(
                        'No matching payment request',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          tx.formattedReceivedAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (tx.upiApp != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tx.upiApp == 'Google Pay'
                                    ? Icons.payment
                                    : Icons.account_balance_wallet_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tx.upiApp!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (tx.transactionReference != null &&
                            tx.paymentStatus == 'REFUNDED')
                          Text(
                            'Ref: ${tx.transactionReference}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                (MediaQuery.of(ctx).padding.bottom > 0
                    ? MediaQuery.of(ctx).padding.bottom + 16
                    : 24),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...['All', 'Successful', 'Pending', 'Unmatched', 'Refunds'].map((f) {
                    return ListTile(
                      title: Text(f),
                      trailing: _selectedFilter == f
                          ? const Icon(Icons.check, color: AppColors.primaryBlue)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _selectedFilter = f);
                        _fetch();
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
