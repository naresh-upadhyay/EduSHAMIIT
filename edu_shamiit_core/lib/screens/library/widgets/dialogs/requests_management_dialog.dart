import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/circulation_provider.dart';
import '../../models/circulation_models.dart';


class RequestsManagementDialog extends ConsumerStatefulWidget {
  const RequestsManagementDialog({super.key});

  @override
  ConsumerState<RequestsManagementDialog> createState() => _RequestsManagementDialogState();
}

class _RequestsManagementDialogState extends ConsumerState<RequestsManagementDialog> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    await ref.read(circulationProvider.notifier).fetchRequests();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(circulationProvider);
    final notifier = ref.read(circulationProvider.notifier);

    final requests = state.requests;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Library Issue & Renewal Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
              )
            else if (requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_rounded, size: 40, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text('No pending book requests.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text('When members request books online, they will show up here for librarian review.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 360,
                child: ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final req = requests[i];
                    return _buildRequestCard(req, notifier, isDark);
                  },
                ),
              ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(LibraryRequestModel req, CirculationNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                req.bookTitle,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(req.status, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Requested by ${req.memberName} (${req.memberCode} • ${req.memberRole}) on ${req.formattedCreatedAt}',
            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          if (req.reason != null && req.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Reason: "${req.reason}"', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Copies: ${req.availableCopies}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: req.availableCopies > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFEF4444)),
                    label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                    onPressed: () => _promptRejection(req.id, notifier),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text('Approve & Issue', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: req.availableCopies > 0
                        ? () async {
                            final ok = await notifier.processRequest(requestId: req.id, action: 'ISSUE');
                            if (ok) _loadRequests();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptRejection(String requestId, CirculationNotifier notifier) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Library Request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(hintText: 'Enter reason for rejection...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () async {
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop();
                final ok = await notifier.processRequest(
                  requestId: requestId,
                  action: 'REJECT',
                  rejectionReason: reasonCtrl.text.trim(),
                );
                if (ok) _loadRequests();
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
