import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/archive_service.dart';
import '../widgets/app_header.dart';
import '../widgets/status_badge.dart';
import 'transaction_details_screen.dart';

class ArchivedTransactionsScreen extends StatefulWidget {
  final VoidCallback? onTransactionsChanged;

  const ArchivedTransactionsScreen({super.key, this.onTransactionsChanged});

  @override
  State<ArchivedTransactionsScreen> createState() => _ArchivedTransactionsScreenState();
}

class _ArchivedTransactionsScreenState extends State<ArchivedTransactionsScreen> {
  List<TransactionItem> _archivedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await _fetchArchivedTransactions();
    if (mounted) {
      setState(() {
        _archivedItems = items;
        _isLoading = false;
      });
    }
  }

  Future<List<TransactionItem>> _fetchArchivedTransactions() async {
    try {
      final all = await ApiService().getTransactions(status: 'All');
      final archivedIds = ArchiveService().archivedTransactionIds;
      return all.where((tx) => archivedIds.contains(tx.id)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _restoreTransaction(TransactionItem tx) async {
    // Immediately remove from local list to avoid Dismissible red error frame during animation
    setState(() {
      _archivedItems.removeWhere((item) => item.id == tx.id);
    });

    await ArchiveService().unarchiveTransaction(tx.id);
    widget.onTransactionsChanged?.call();

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Restored transaction ${tx.formattedAmount} to active ledger'),
          backgroundColor: AppColors.successGreen,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Future.delayed(const Duration(milliseconds: 5200), () {
        if (mounted) {
          messenger.hideCurrentSnackBar();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            const AppHeader(
              title: 'Archived Transactions',
              showBackButton: true,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unmatched & unverified payments swiped left or right are archived here. Verified payments remain immutable in the active ledger.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _archivedItems.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _archivedItems.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.6,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryNavy.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.archive_outlined, size: 48, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Archived Transactions',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Swipe right or left on any unmatched transaction\nto move it to this archive repository.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16, 12, 16, (bottomInset > 0 ? bottomInset : 24) + 24),
                            itemCount: _archivedItems.length,
                            itemBuilder: (context, index) {
                              final tx = _archivedItems[index];
                              return _buildArchivedCard(tx);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedCard(TransactionItem tx) {
    return Dismissible(
      key: Key('archived_tx_${tx.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.unarchive_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Restore to Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.successGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Restore to Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.unarchive_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      onDismissed: (_) => _restoreTransaction(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tx.upiApp ?? 'UPI App',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: tx.paymentStatus),
                  const Spacer(),
                  Text(
                    tx.formattedTime,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.studentName ?? tx.maskedSender ?? 'Unmatched Payer',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        if (tx.transactionReference != null && tx.transactionReference!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Ref: ${tx.transactionReference}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    tx.formattedAmount,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailsScreen(transactionId: tx.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 14),
                    label: const Text('View Details', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _restoreTransaction(tx),
                    icon: const Icon(Icons.unarchive_rounded, size: 14),
                    label: const Text('Restore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
