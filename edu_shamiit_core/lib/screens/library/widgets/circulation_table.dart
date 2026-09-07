import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import '../models/circulation_models.dart';
import '../providers/circulation_provider.dart';
import 'dialogs/quick_return_dialog.dart';
import 'dialogs/renew_book_dialog.dart';
import 'dialogs/fine_collection_dialog.dart';
import 'dialogs/process_issue_request_dialog.dart';
import 'dialogs/request_renew_dialog.dart';
import 'dialogs/request_return_dialog.dart';

class CirculationTable extends ConsumerStatefulWidget {
  const CirculationTable({super.key});

  @override
  ConsumerState<CirculationTable> createState() => _CirculationTableState();
}

class _CirculationTableState extends ConsumerState<CirculationTable> {
  final ScrollController _horizontalScrollCtrl = ScrollController();

  @override
  void dispose() {
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userData?['id']?.toString() ??
        authState.userData?['profile_id']?.toString() ??
        authState.userData?['user_id']?.toString();

    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Subtabs Row + Export & Columns Buttons
          _buildSubtabsHeader(context, state, notifier, isDark),

          // 2. Table or Loader/Empty State
          if (state.isLoading && state.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              ),
            )
          else if (state.transactions.isEmpty)
            _buildEmptyState(isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const minTableWidth = 1200.0;
                final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

                return Scrollbar(
                  controller: _horizontalScrollCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTableHeader(state, notifier, isDark),
                          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          ...state.transactions.map((tx) {
                            final isSelected = state.selectedBorrowIds.contains(tx.id);
                            return _buildTableRow(context, tx, isSelected, notifier, isDark, isLibraryAdmin, currentUserId);
                          }),

                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

          // 3. Table Pagination Footer
          _buildPaginationFooter(context, state, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildTableHeader(CirculationState state, CirculationNotifier notifier, bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          // 1. Checkbox
          SizedBox(
            width: 28,
            child: Checkbox(
              value: state.selectedBorrowIds.length == state.transactions.length && state.transactions.isNotEmpty,
              onChanged: (val) => notifier.selectAll(val ?? false),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Transaction ID (flex: 13)
          Expanded(flex: 13, child: _buildSortHeader('Txn Code', 'transaction_code', state, notifier)),
          const SizedBox(width: 10),

          // 3. Member (flex: 18)
          Expanded(flex: 18, child: _buildSortHeader('Borrower / Member', 'member_name', state, notifier)),
          const SizedBox(width: 10),

          // 4. Book (flex: 20)
          Expanded(flex: 20, child: _buildSortHeader('Book Title', 'book_title', state, notifier)),
          const SizedBox(width: 10),

          // 5. Issue Date (flex: 11)
          Expanded(flex: 11, child: _buildSortHeader('Issue Date', 'issue_date', state, notifier)),
          const SizedBox(width: 10),

          // 6. Due Date (flex: 11)
          Expanded(flex: 11, child: _buildSortHeader('Due Date', 'due_date', state, notifier)),
          const SizedBox(width: 10),

          // 7. Return Date (flex: 11)
          Expanded(flex: 11, child: _buildSortHeader('Return Date', 'return_date', state, notifier)),
          const SizedBox(width: 10),

          // 8. Status (flex: 10)
          Expanded(flex: 10, child: _buildSortHeader('Status', 'status', state, notifier)),
          const SizedBox(width: 10),

          // 9. Fine (flex: 10)
          Expanded(flex: 10, child: _buildSortHeader('Fine (₹)', 'fine_amount', state, notifier)),
          const SizedBox(width: 10),

          // 10. Type (flex: 11)
          Expanded(flex: 11, child: _buildSortHeader('Type', 'transaction_type', state, notifier)),
          const SizedBox(width: 10),

          // 11. Actions (width: 150)
          const SizedBox(
            width: 150,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildTableRow(
    BuildContext context,
    LibraryTransactionModel tx,
    bool isSelected,
    CirculationNotifier notifier,
    bool isDark,
    bool isLibraryAdmin,
    String? currentUserId,
  ) {
    final isPendingWithoutAction = ['PENDING', 'REQUESTED', 'NEW', 'PENDING_RENEW', 'PENDING_RETURN'].contains(tx.status.toUpperCase());
    final isCreator = currentUserId != null &&
        tx.memberUserId != null &&
        currentUserId.trim().isNotEmpty &&
        tx.memberUserId!.trim().toLowerCase() == currentUserId.trim().toLowerCase();
    final canDeleteBorrow = isPendingWithoutAction && isCreator;

    return Container(

      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.16 : 0.06)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 1. Checkbox
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => notifier.toggleSelection(tx.id),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Transaction ID (Monospace)
              Expanded(
                flex: 13,
                child: InkWell(
                  onTap: () => notifier.openDetails(tx),
                  child: Text(
                    tx.transactionCode,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 3. Member (Avatar + Name + Subtitle)
              Expanded(
                flex: 18,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        tx.memberName.isNotEmpty ? tx.memberName[0].toUpperCase() : 'M',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.memberName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${tx.memberCode} • ${tx.memberType}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 4. Book (Title + ISBN)
              Expanded(
                flex: 20,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'ISBN: ${tx.bookIsbn}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 5. Issue Date
              Expanded(
                flex: 11,
                child: Text(
                  tx.formattedIssueDate,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 6. Due Date
              Expanded(
                flex: 11,
                child: Text(
                  tx.formattedDueDate,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 7. Return Date
              Expanded(
                flex: 11,
                child: Text(
                  tx.formattedReturnDate,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 8. Status Badge
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(tx.status),
                ),
              ),
              const SizedBox(width: 10),

              // 9. Fine (INR)
              Expanded(
                flex: 10,
                child: Text(
                  tx.formattedFine,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tx.fineAmount > 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 10. Type
              Expanded(
                flex: 11,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getTypeIcon(tx.transactionType), size: 13, color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tx.displayTransactionType,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 11. Actions (width: 150)
              SizedBox(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (canDeleteBorrow)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Delete / Cancel Request',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _confirmDeleteBorrow(context, tx, notifier),
                      ),
                    if (isLibraryAdmin) ...[

                      // Librarian Actions: Process Request to Issue
                      if (tx.transactionType.toUpperCase() == 'REQUEST_TO_ISSUE' ||
                          ['PENDING', 'WAITING', 'REQUESTED'].contains(tx.status.toUpperCase()))
                        IconButton(
                          icon: const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF10B981)),
                          tooltip: 'Process / Issue Request',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ProcessIssueRequestDialog(transaction: tx),
                            );
                          },
                        ),
                      // Librarian Actions: Process Renewal Request
                      if (tx.transactionType.toUpperCase() == 'RENEW_REQUEST' ||
                          tx.status.toUpperCase() == 'PENDING_RENEW')
                        IconButton(
                          icon: const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF8B5CF6)),
                          tooltip: 'Process / Renew Book',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => RenewBookDialog(transaction: tx),
                            );
                          },
                        ),
                      // Librarian Actions: Process Return Request
                      if (tx.transactionType.toUpperCase() == 'RETURN_REQUEST' ||
                          tx.status.toUpperCase() == 'PENDING_RETURN')
                        IconButton(
                          icon: const Icon(Icons.keyboard_return_rounded, size: 18, color: Color(0xFF10B981)),
                          tooltip: 'Process / Return Book',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QuickReturnDialog(
                                initialBarcodeQuery: tx.copyBarcode,
                                transaction: tx,
                              ),
                            );
                          },
                        ),
                      if (['ISSUED', 'BORROWED', 'OVERDUE', 'RENEWED'].contains(tx.status.toUpperCase())) ...[
                        // Return Icon Button
                        IconButton(
                          icon: const Icon(Icons.keyboard_return_rounded, size: 16, color: Color(0xFF10B981)),
                          tooltip: 'Return Book',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => QuickReturnDialog(
                                initialBarcodeQuery: tx.copyBarcode,
                                transaction: tx,
                              ),
                            );
                          },
                        ),
                        // Renew Icon Button
                        IconButton(
                          icon: const Icon(Icons.autorenew_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          tooltip: 'Renew Book',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => RenewBookDialog(transaction: tx),
                            );
                          },
                        ),
                      ],
                    ] else ...[
                      // Student / Teacher / Non-Admin Actions: Only for actively issued/borrowed/overdue/renewed
                      if (['ISSUED', 'BORROWED', 'OVERDUE', 'RENEWED'].contains(tx.status.toUpperCase())) ...[
                        IconButton(
                          icon: const Icon(Icons.autorenew_rounded, size: 18, color: Color(0xFF8B5CF6)),
                          tooltip: 'Request Renewal',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => RequestRenewDialog(transaction: tx),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.keyboard_return_rounded, size: 18, color: Color(0xFF10B981)),
                          tooltip: 'Request Return',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          onPressed: () => _confirmRequestReturn(context, tx, notifier),
                        ),
                      ],
                    ],
                    // View Details
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF6366F1)),
                      tooltip: 'View Details',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: () => notifier.openDetails(tx),
                    ),
                    if (isLibraryAdmin) ...[
                      // More Actions Menu (Fine collection, etc.)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onSelected: (val) {
                          if (val == 'fine') {
                            showDialog(context: context, builder: (_) => FineCollectionDialog(memberId: tx.memberId));
                          } else if (val == 'details') {
                            notifier.openDetails(tx);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'details', child: Text('View Details Drawer')),
                          if (tx.fineAmount > 0)
                            const PopupMenuItem(value: 'fine', child: Text('Collect / Settle Fine')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtabsHeader(
    BuildContext context,
    CirculationState state,
    CirculationNotifier notifier,
    bool isDark,
  ) {
    final subtabs = [
      {'key': 'ALL', 'label': 'All Transactions'},
      {'key': 'ISSUED', 'label': 'Issued'},
      {'key': 'RETURNED', 'label': 'Returned'},
      {'key': 'OVERDUE', 'label': 'Overdue'},
      {'key': 'REQUESTS', 'label': 'Requests'},
      {'key': 'RENEWED', 'label': 'Renewed'},
      {'key': 'LOST_DAMAGED', 'label': 'Lost / Damaged'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Subtabs scrollable list
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: subtabs.map((tab) {
                  final key = tab['key']!;
                  final label = tab['label']!;
                  final isActive = state.subtab == key ||
                      (key == 'ISSUED' && state.subtab == 'ISSUED_TODAY') ||
                      (key == 'RETURNED' && state.subtab == 'RETURNED_TODAY') ||
                      (key == 'ALL' && state.subtab == 'FINES');
                  final count = state.subtabCounts[key] ?? state.subtabCounts[key.toUpperCase()];

                  return InkWell(
                    onTap: () => notifier.setSubtab(key),
                    child: Container(
                      margin: const EdgeInsets.only(right: 18),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                              color: isActive
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (count != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Top Right Buttons (Export, Columns)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 15),
                label: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text('Columns', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155))),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'reset', child: Text('Reset to Default View')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortHeader(String label, String sortKey, CirculationState state, CirculationNotifier notifier) {
    final isCurrent = state.sortBy == sortKey;
    final isAsc = state.sortOrder.toLowerCase() == 'asc';

    return InkWell(
      onTap: () => notifier.setSorting(sortKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            isCurrent ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded,
            size: 13,
            color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.toUpperCase();
    Color bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    Color fg = const Color(0xFF3B82F6);

    if (s == 'RETURNED') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
    } else if (s == 'OVERDUE' || s == 'LOST' || s == 'REJECTED') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFEF4444);
    } else if (s == 'RENEWED') {
      bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
      fg = const Color(0xFF8B5CF6);
    } else if (s == 'DAMAGED' || s == 'PENDING' || s == 'WAITING' || s == 'REQUESTED' || s == 'PENDING_RENEW' || s == 'PENDING_RETURN') {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      fg = const Color(0xFFF59E0B);
    }

    String displayLabel = s;
    if (s == 'PENDING_RENEW') displayLabel = 'RENEW REQ';
    if (s == 'PENDING_RETURN') displayLabel = 'RETURN REQ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    final t = type.toUpperCase();
    if (t == 'REQUEST_APPROVED') return Icons.check_circle_outline_rounded;
    if (t.contains('RETURN')) return Icons.assignment_return_outlined;
    if (t.contains('RENEW')) return Icons.autorenew_rounded;
    if (t.contains('ISSUE') || t.contains('REQUEST')) return Icons.outbox_rounded;
    return Icons.menu_book_rounded;
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded, size: 48, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            'No circulation transactions found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search criteria or date filters.',
            style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(
    BuildContext context,
    CirculationState state,
    CirculationNotifier notifier,
    bool isDark,
  ) {
    final start = state.totalTransactions == 0 ? 0 : (state.page - 1) * state.pageSize + 1;
    final end = (state.page * state.pageSize).clamp(0, state.totalTransactions);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // "Showing X to Y of Z transactions"
          Text(
            'Showing $start to $end of ${state.totalTransactions} transactions',
            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),

          // Page size + Navigation controls
          Row(
            children: [
              // Page size dropdown
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.pageSize,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    items: const [10, 25, 50, 100].map((size) => DropdownMenuItem(value: size, child: Text('$size per page'))).toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setPageSize(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Previous Button
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
              ),

              // Page indicator
              Text(
                '${state.page} / ${state.totalPages.clamp(1, 9999)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),

              // Next Button
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteBorrow(
    BuildContext context,
    LibraryTransactionModel tx,
    CirculationNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Borrow Request',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel and delete this circulation request? This action cannot be undone.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.book_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.transactionCode,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          tx.bookTitle,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await notifier.deleteBorrowRequest(tx.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Borrow request ${tx.transactionCode} deleted successfully.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorText = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorText.isNotEmpty ? errorText : 'Failed to delete borrow request.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmRequestReturn(
    BuildContext context,
    LibraryTransactionModel tx,
    CirculationNotifier notifier,
  ) async {
    await RequestReturnDialog.show(context, transaction: tx);
  }
}


