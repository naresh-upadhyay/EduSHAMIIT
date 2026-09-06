import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/member_models.dart';
import '../../providers/member_provider.dart';

class SuspendMemberDialog extends ConsumerStatefulWidget {
  final LibraryMemberModel member;
  const SuspendMemberDialog({super.key, required this.member});

  @override
  ConsumerState<SuspendMemberDialog> createState() => _SuspendMemberDialogState();
}

class _SuspendMemberDialogState extends ConsumerState<SuspendMemberDialog> {
  final TextEditingController _reasonCtrl = TextEditingController(text: 'Long overdue / unreturned library materials');
  String _selectedQuickReason = 'Overdue books';

  final _quickReasons = [
    'Overdue books',
    'Unpaid fines',
    'Damaged library property',
    'Disciplinary action',
    'Custom reason',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suspend Library Membership',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                        ),
                        Text(
                          '${widget.member.memberName} (${widget.member.memberCode})',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFEF4444)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.member.booksIssued > 0
                                ? 'This member currently has ${widget.member.booksIssued} issued book(s). Suspending will prevent new book checkouts and renewals.'
                                : 'Suspending this member will immediately block all library borrowing privileges.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick reasons
                  const Text(
                    'Select Suspension Reason',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickReasons.map((r) {
                      final isSelected = _selectedQuickReason == r;
                      return ChoiceChip(
                        label: Text(r, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedQuickReason = r;
                              if (r != 'Custom reason') {
                                _reasonCtrl.text = r;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Custom reason text
                  TextField(
                    controller: _reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Detailed Reason / Audit Note *',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: state.isActionLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.block_rounded, size: 17),
                    label: const Text('Suspend Member', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isActionLoading ? null : _submitSuspension,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitSuspension() async {
    final success = await ref.read(memberProvider.notifier).suspendMember(
      widget.member.id,
      reason: _reasonCtrl.text.trim(),
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
