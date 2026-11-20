import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';
import '../widgets/filter_chips.dart';
import '../widgets/status_badge.dart';
import '../widgets/phonepe_filter_dialog.dart';
import '../services/archive_service.dart';
import 'archived_transactions_screen.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TransactionsScreen({super.key, this.onBack});

  @override
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  PhonePeFilterState _filterState = const PhonePeFilterState();

  late Future<List<TransactionItem>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refresh() {
    _fetch();
  }

  void _fetch() {
    setState(() {
      _transactionsFuture = ApiService().getTransactions(
        status: _selectedFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    });
  }

  Future<void> _openPhonePeFilters() async {
    final result = await showDialog<PhonePeFilterState>(
      context: context,
      builder: (_) => PhonePeFilterDialog(
        initialState: _filterState,
        isForAlerts: false,
      ),
    );
    if (result != null) {
      setState(() {
        _filterState = result;
      });
    }
  }

  List<TransactionItem> _applyAllFilters(List<TransactionItem> raw) {
    return raw.where((tx) {
      // 0. Exclude archived transactions
      if (ArchiveService().isTransactionArchived(tx.id)) return false;

      // 1. Text Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesQuery = (tx.transactionReference?.toLowerCase().contains(q) ?? false) ||
            tx.formattedAmount.toLowerCase().contains(q) ||
            (tx.studentName?.toLowerCase().contains(q) ?? false) ||
            (tx.invoiceNumber?.toLowerCase().contains(q) ?? false) ||
            (tx.intentReference?.toLowerCase().contains(q) ?? false) ||
            (tx.upiApp?.toLowerCase().contains(q) ?? false);
        if (!matchesQuery) return false;
      }

      // 2. Month Filter
      if (_filterState.selectedMonths.isNotEmpty) {
        final dt = tx.receivedDateTime;
        final monthStr = DateFormat('MMM yyyy').format(dt).toLowerCase();
        final matchesMonth = _filterState.selectedMonths.any((m) =>
            m.toLowerCase().contains(monthStr) || monthStr.contains(m.toLowerCase().split(' ').first));
        if (!matchesMonth) return false;
      }

      // 3. Instrument / App Filter
      if (_filterState.selectedInstruments.isNotEmpty) {
        final matchesApp = _filterState.selectedInstruments.any((inst) {
          final instLower = inst.toLowerCase();
          final appLower = (tx.upiApp ?? '').toLowerCase();
          return appLower.contains(instLower) || instLower.contains(appLower);
        });
        if (!matchesApp) return false;
      }

      // 4. Status Filter
      if (_filterState.selectedStatuses.isNotEmpty) {
        final st = tx.paymentStatus.toUpperCase();
        bool matchesStatus = false;
        for (final s in _filterState.selectedStatuses) {
          final sUpper = s.toUpperCase();
          if (sUpper.contains('SUCCESS') && (st.contains('SUCCESS') || st.contains('VERIF'))) matchesStatus = true;
          if (sUpper.contains('PENDING') && (st.contains('PENDING') || st.contains('AWAITING'))) matchesStatus = true;
          if (sUpper.contains('UNMATCHED') && st.contains('UNMATCHED')) matchesStatus = true;
          if (sUpper.contains('REFUND') && st.contains('REFUND')) matchesStatus = true;
          if (sUpper.contains('REVIEW') && st.contains('REVIEW')) matchesStatus = true;
        }
        if (!matchesStatus) return false;
      }

      // 5. Payment Types Filter
      if (_filterState.selectedPaymentTypes.isNotEmpty) {
        final isCredit = !tx.paymentStatus.toUpperCase().contains('REFUND');
        final wantsCredit = _filterState.selectedPaymentTypes.any((t) => t.toLowerCase().contains('credit') || t.toLowerCase().contains('received'));
        final wantsDebit = _filterState.selectedPaymentTypes.any((t) => t.toLowerCase().contains('debit') || t.toLowerCase().contains('sent'));
        if (isCredit && !wantsCredit && wantsDebit) return false;
        if (!isCredit && !wantsDebit && wantsCredit) return false;
      }

      return true;
    }).toList();
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
                icon: const Icon(Icons.archive_outlined, color: Colors.white),
                tooltip: 'Archived Transactions',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArchivedTransactionsScreen(
                        onTransactionsChanged: _fetch,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Ledger',
                onPressed: _fetch,
              ),
            ],
          ),

          // PhonePe-Style Search & Filters Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search student, invoice, or UTR...',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                Container(
                  height: 20,
                  width: 1,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune_rounded, size: 20, color: AppColors.primaryNavy),
                      if (!_filterState.isEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5F259F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'PhonePe-Style Filters',
                  onPressed: _openPhonePeFilters,
                ),
              ],
            ),
          ),

          // Active Filters Pills Bar
          if (!_filterState.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ..._filterState.selectedMonths.map((m) => _buildActiveFilterChip(m, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedMonths: Set.from(_filterState.selectedMonths)..remove(m),
                            );
                          });
                        })),
                    ..._filterState.selectedInstruments.map((inst) => _buildActiveFilterChip(inst, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedInstruments: Set.from(_filterState.selectedInstruments)..remove(inst),
                            );
                          });
                        })),
                    ..._filterState.selectedStatuses.map((st) => _buildActiveFilterChip(st, () {
                          setState(() {
                            _filterState = _filterState.copyWith(
                              selectedStatuses: Set.from(_filterState.selectedStatuses)..remove(st),
                            );
                          });
                        })),
                    InkWell(
                      onTap: () {
                        setState(() => _filterState = const PhonePeFilterState());
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'Clear all',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Horizontal Quick Filter Chips Bar
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

          // Transactions List Grouped by Month
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _fetch(),
              child: FutureBuilder<List<TransactionItem>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return RefreshIndicator(
                      onRefresh: () async => _fetch(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.5,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off, size: 48, color: AppColors.errorRed),
                              const SizedBox(height: 12),
                              const Text('Offline: Could not connect to server', style: TextStyle(color: AppColors.errorRed)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _fetch,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final rawItems = snapshot.data ?? [];
                  final filteredItems = _applyAllFilters(rawItems);

                  if (filteredItems.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _fetch(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.5,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty || !_filterState.isEmpty
                                    ? 'No transactions match your filters'
                                    : 'No transactions found',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Group by Month (matching PhonePe screenshot: e.g. "November 2026")
                  final grouped = <String, List<TransactionItem>>{};
                  for (final item in filteredItems) {
                    final dt = item.receivedDateTime;
                    final monthKey = DateFormat('MMMM yyyy').format(dt);
                    grouped.putIfAbsent(monthKey, () => []).add(item);
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, idx) {
                      final monthKey = grouped.keys.elementAt(idx);
                      final monthItems = grouped[monthKey]!;
                      final monthTotal = monthItems.fold<double>(0.0, (acc, item) => acc + item.amountDouble);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month Header with Total Volume (matching Screenshot 2: "November 2026   ₹52,797.25 >")
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    monthKey,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${monthTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Month's Transactions
                          ...monthItems.map((tx) => _buildPhonePeTransactionCard(tx)),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF5F259F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5F259F).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5F259F))),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: Color(0xFF5F259F)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePeTransactionCard(TransactionItem tx) {
    Color iconBg = const Color(0xFF2563EB);
    Widget iconContent = const Icon(Icons.payment, color: Colors.white, size: 18);

    final appLower = (tx.upiApp ?? '').toLowerCase();
    if (appLower.contains('phonepe')) {
      iconBg = const Color(0xFF5F259F);
      iconContent = const Text('पे', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    } else if (appLower.contains('google') || appLower.contains('gpay')) {
      iconBg = const Color(0xFF4285F4);
      iconContent = const Text('G', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    } else if (appLower.contains('paytm')) {
      iconBg = const Color(0xFF002E6E);
      iconContent = const Text('P', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    } else if (appLower.contains('bhim')) {
      iconBg = const Color(0xFF00796B);
      iconContent = const Text('B', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
    } else if (appLower.contains('canara')) {
      iconBg = const Color(0xFF003B70);
      iconContent = const Text('CB', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
    } else if (appLower.contains('sms')) {
      iconBg = const Color(0xFF0284C7);
      iconContent = const Icon(Icons.sms_outlined, color: Colors.white, size: 16);
    }

    final isRefund = tx.paymentStatus.toUpperCase().contains('REFUND');
    final amountSign = isRefund ? '- ' : '+ ';
    final amountColor = isRefund ? AppColors.textSecondary : AppColors.successGreen;

    final cardWidget = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailsScreen(transactionId: tx.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Payment Mode / UPI App Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(child: iconContent),
              ),
              const SizedBox(width: 12),

              // 2. Center Transaction Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Student / Payer Name
                    Text(
                      tx.studentName != null && tx.studentName!.isNotEmpty
                          ? tx.studentName!
                          : (tx.maskedSender != null ? 'Payer ${tx.maskedSender}' : 'Direct UPI Deposit'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Invoice Number & Time
                    Text(
                      tx.invoiceNumber != null && tx.invoiceNumber!.isNotEmpty
                          ? '${tx.invoiceNumber} • ${tx.formattedTime}'
                          : tx.formattedTime,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Status Badge & Reference
                    Row(
                      children: [
                        StatusBadge(
                          status: tx.paymentStatus,
                        ),
                        if (tx.transactionReference != null && tx.transactionReference!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ref: ${tx.transactionReference}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 3. Right: Amount, Credited/Debited Status & Chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$amountSign${tx.formattedAmount}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: amountColor),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isRefund ? 'Debited' : 'Credited to UPI',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key('tx_${tx.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (!tx.canArchive) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Matched & successful transactions are immutable financial records and cannot be archived.',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.errorRed,
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Future.delayed(const Duration(milliseconds: 5200), () {
            if (mounted) messenger.hideCurrentSnackBar();
          });
          return false;
        }
        return true;
      },
      onDismissed: (direction) async {
        await ArchiveService().archiveTransaction(tx.id);
        _fetch();
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Archived ${tx.formattedAmount} transaction'),
              backgroundColor: AppColors.primaryNavy,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'UNDO',
                textColor: AppColors.primaryBlueLight,
                onPressed: () async {
                  await ArchiveService().unarchiveTransaction(tx.id);
                  _fetch();
                },
              ),
            ),
          );
          Future.delayed(const Duration(milliseconds: 5200), () {
            if (mounted) {
              messenger.hideCurrentSnackBar();
            }
          });
        }
      },
      background: _buildArchiveSwipeBackground(Alignment.centerLeft),
      secondaryBackground: _buildArchiveSwipeBackground(Alignment.centerRight),
      child: cardWidget,
    );
  }

  Widget _buildArchiveSwipeBackground(Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.archive_outlined, color: Colors.white, size: 20),
          SizedBox(width: 6),
          Text(
            'Archive',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
