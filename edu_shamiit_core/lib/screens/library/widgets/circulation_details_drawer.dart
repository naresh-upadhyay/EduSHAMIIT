import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/circulation_provider.dart';
import 'dialogs/quick_return_dialog.dart';
import 'dialogs/renew_book_dialog.dart';
import 'dialogs/fine_collection_dialog.dart';

class CirculationDetailsDrawer extends ConsumerWidget {
  const CirculationDetailsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = state.selectedTransaction;
    if (data == null) {
      return Container(
        width: 440,
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    final book = data['book'] is Map ? data['book'] as Map<String, dynamic> : <String, dynamic>{};
    final member = data['member'] is Map ? data['member'] as Map<String, dynamic> : <String, dynamic>{};
    final copy = data['copy'] is Map ? data['copy'] as Map<String, dynamic> : <String, dynamic>{};
    final fine = data['fine'] is Map ? data['fine'] as Map<String, dynamic> : <String, dynamic>{};
    final timeline = data['timeline'] is List ? (data['timeline'] as List) : <dynamic>[];

    final status = (data['status']?.toString() ?? 'ISSUED').toUpperCase();

    return Container(
      width: 440,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          left: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      data['transaction_code']?.toString() ?? 'Transaction Detail',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(status),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => notifier.closeDrawer(),
                ),
              ],
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Book Card
                  _buildSectionTitle('Book Details', isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (book['cover_url'] != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              book['cover_url'].toString(),
                              width: 48,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildBookPlaceholder(),
                            ),
                          )
                        else
                          _buildBookPlaceholder(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['title']?.toString() ?? 'Untitled Book',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text('By ${book['author'] ?? 'Unknown'}', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              Text('ISBN: ${book['isbn'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              Text('Barcode: ${copy['barcode'] ?? 'N/A'} • Accession: ${copy['accession_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              if (copy['shelf_location'] != null)
                                Text('Location: ${copy['shelf_location']}', style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Member Card
                  _buildSectionTitle('Borrower Profile', isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF6366F1),
                          child: Text(
                            (member['name']?.toString().isNotEmpty ?? false) ? member['name'][0].toUpperCase() : 'M',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['name']?.toString() ?? 'Unknown Member',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Text('${member['member_code'] ?? 'N/A'} • ${member['role'] ?? 'Student'} • ${member['class'] ?? member['department'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              if (member['phone'] != null)
                                Text('Phone: ${member['phone']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Loan Timeline Details
                  _buildSectionTitle('Loan Timeline', isDark),
                  const SizedBox(height: 8),
                  _buildDetailRow('Issue Date', _formatDate(data['issue_date']), isDark),
                  _buildDetailRow('Due Date', _formatDate(data['due_date']), isDark),
                  _buildDetailRow('Return Date', data['return_date'] != null ? _formatDate(data['return_date']) : '—', isDark),
                  _buildDetailRow('Days Overdue', '${data['days_overdue'] ?? 0} days', isDark, isAlert: (data['days_overdue'] as num? ?? 0) > 0),
                  _buildDetailRow('Renewals Used', '${data['renewals_used'] ?? 0} / ${data['max_renewals'] ?? 2}', isDark),
                  _buildDetailRow('Issued By', data['issued_by_name']?.toString() ?? 'System / Admin', isDark),
                  if (data['notes'] != null) _buildDetailRow('Notes', data['notes'].toString(), isDark),
                  const SizedBox(height: 16),

                  // Fine Details
                  if (fine['amount'] != null && (fine['amount'] as num) > 0) ...[
                    _buildSectionTitle('Fine Assessment', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Fine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('₹${(fine['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Outstanding Amount', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text('₹${(fine['outstanding_amount'] as num? ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Activity Lifecycle Timeline
                  if (timeline.isNotEmpty) ...[
                    _buildSectionTitle('Activity & Audit Trail', isDark),
                    const SizedBox(height: 8),
                    Column(
                      children: timeline.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(Icons.circle, size: 8, color: Color(0xFF6366F1)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry['action']?.toString() ?? 'Updated',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                              Text(
                                _formatDate(entry['created_at']),
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Footer Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (status == 'ISSUED' || status == 'OVERDUE' || status == 'RENEWED') ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                    label: const Text('Return Book', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      notifier.closeDrawer();
                      showDialog(
                        context: context,
                        builder: (_) => QuickReturnDialog(initialBarcodeQuery: copy['barcode']?.toString()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.autorenew_rounded, size: 16),
                    label: const Text('Renew Loan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B5CF6),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      notifier.closeDrawer();
                      showDialog(
                        context: context,
                        builder: (_) => RenewBookDialog(borrowId: data['id']?.toString()),
                      );
                    },
                  ),
                ],
                if (fine['amount'] != null && (fine['outstanding_amount'] as num? ?? 0) > 0)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.currency_rupee_rounded, size: 16),
                    label: const Text('Collect Fine', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      notifier.closeDrawer();
                      showDialog(
                        context: context,
                        builder: (_) => FineCollectionDialog(
                          fineId: fine['id']?.toString(),
                          memberId: member['id']?.toString(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAlert ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookPlaceholder() {
    return Container(
      width: 48,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 24),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    Color fg = const Color(0xFF3B82F6);

    if (status == 'RETURNED') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.12);
      fg = const Color(0xFF10B981);
    } else if (status == 'OVERDUE' || status == 'LOST') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      fg = const Color(0xFFEF4444);
    } else if (status == 'RENEWED') {
      bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
      fg = const Color(0xFF8B5CF6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    if (date is DateTime) return DateFormat('dd MMM yyyy').format(date);
    final parsed = DateTime.tryParse(date.toString());
    return parsed != null ? DateFormat('dd MMM yyyy').format(parsed) : date.toString();
  }
}
