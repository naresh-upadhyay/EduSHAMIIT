import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';

/// Librarian Drawer for Managing Digital Permissions and Reader Access for a Book
class BookAccessDrawer extends ConsumerStatefulWidget {
  final BookModel book;

  const BookAccessDrawer({
    super.key,
    required this.book,
  });

  @override
  ConsumerState<BookAccessDrawer> createState() => _BookAccessDrawerState();
}

class _BookAccessDrawerState extends ConsumerState<BookAccessDrawer> {
  final TextEditingController _customDaysController =
      TextEditingController(text: '30');

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final perms = state.selectedBookPermissions;
    final analytics =
        state.selectedBookAnalytics ?? const DigitalAnalyticsModel();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 480,
      color: isDark ? const Color(0xFF131B2E) : Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: isDark
                  ? const Border(
                      bottom: BorderSide(color: Color(0xFF1E293B)),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Color(0xFF818CF8), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Digital Access Management',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      Text(
                        widget.book.title,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () =>
                      ref.read(bookProvider.notifier).closeAccessDrawer(),
                ),
              ],
            ),
          ),

          // Digital Engagement Quick Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: Row(
              children: [
                _metricBox('Total Reads', '${analytics.totalReads}',
                    Icons.visibility, Colors.indigo, isDark),
                const SizedBox(width: 8),
                _metricBox(
                    'Hours Spent',
                    '${analytics.totalReadingHours.toStringAsFixed(1)}h',
                    Icons.timer,
                    Colors.teal,
                    isDark),
                const SizedBox(width: 8),
                _metricBox('Active Readers', '${analytics.uniqueReaders}',
                    Icons.people, Colors.purple, isDark),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),

          // Permissions List
          Expanded(
            child: state.isActionLoading
                ? const Center(child: CircularProgressIndicator())
                : perms.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open,
                                size: 48,
                                color: isDark
                                    ? const Color(0xFF475569)
                                    : Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'No user permission requests found.',
                              style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.book.requiresPermission
                                  ? 'This book is RESTRICTED. Requests will appear here.'
                                  : 'This book has OPEN PUBLIC ACCESS.',
                              style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: perms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final perm = perms[idx];
                          return _buildPermissionCard(context, perm, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(
      String title, String val, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
              ],
            ),
            const SizedBox(height: 4),
            Text(val,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E293B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
      BuildContext context, DigitalAccessPermissionModel perm, bool isDark) {
    final isPending = perm.status == 'PENDING';
    final isApproved = perm.status == 'APPROVED';
    final isExpired = perm.isExpired;

    Color badgeColor = Colors.grey;
    String badgeText = perm.status;
    if (isPending) {
      badgeColor = Colors.amber[700]!;
    } else if (isApproved && !isExpired) {
      badgeColor = const Color(0xFF10B981);
      badgeText = 'ACTIVE';
    } else if (isExpired) {
      badgeColor = Colors.red;
      badgeText = 'EXPIRED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isPending
                ? (isDark ? Colors.amber[700]! : Colors.amber[300]!)
                : (isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                backgroundImage: perm.userAvatar != null
                    ? NetworkImage(perm.userAvatar!)
                    : null,
                child: perm.userAvatar == null
                    ? Text(
                        (perm.userName ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perm.userName ?? 'Library User',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                    Text(
                      '${perm.userRole ?? 'Student'} • ${perm.userEmail ?? ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (perm.reason != null && perm.reason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: "${perm.reason}"',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569)),
              ),
            ),
          ],
          if (perm.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Expires: ${DateFormat('dd MMM yyyy').format(perm.expiresAt!)}',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 12),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _grantPermission(perm.userId, 30),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve (30 Days)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ] else if (isApproved && !isExpired) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _revokePermission(perm.userId),
                  icon: const Icon(Icons.block, size: 14),
                  label: const Text('Revoke Access',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _grantPermission(String userId, int durationDays) async {
    await ref
        .read(bookProvider.notifier)
        .grantDigitalPermission(widget.book.id, {
      'user_id': userId,
      'status': 'APPROVED',
      'duration_days': durationDays,
      'access_scope': 'FULL',
      'reason': 'Approved by Librarian for $durationDays days.',
    });
  }

  Future<void> _revokePermission(String userId) async {
    await ref
        .read(bookProvider.notifier)
        .revokeDigitalPermission(widget.book.id, userId);
  }
}
