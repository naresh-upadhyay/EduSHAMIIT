import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/member_provider.dart';

class BulkMembersDialog extends ConsumerStatefulWidget {
  const BulkMembersDialog({super.key});

  @override
  ConsumerState<BulkMembersDialog> createState() => _BulkMembersDialogState();
}

class _BulkMembersDialogState extends ConsumerState<BulkMembersDialog> {
  String _selectedAction = 'ACTIVATE';
  final TextEditingController _reasonCtrl = TextEditingController(text: 'Bulk administrative suspension');
  final TextEditingController _limitCtrl = TextEditingController(text: '3');
  String _targetMembershipType = 'Student';

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = state.selectedMemberIds.length;

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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.checklist_rtl_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bulk Operations on Members',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '$selectedCount member(s) currently selected',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
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
                  const Text(
                    'Select Action to Apply',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: _selectedAction,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVATE', child: Text('Activate Members')),
                      DropdownMenuItem(value: 'SUSPEND', child: Text('Suspend Members')),
                      DropdownMenuItem(value: 'RENEW', child: Text('Renew Memberships (1 Year)')),
                      DropdownMenuItem(value: 'CHANGE_LIMIT', child: Text('Change Borrowing Limit')),
                      DropdownMenuItem(value: 'CHANGE_TYPE', child: Text('Change Membership Type')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAction = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  if (_selectedAction == 'SUSPEND') ...[
                    TextField(
                      controller: _reasonCtrl,
                      decoration: InputDecoration(
                        labelText: 'Suspension Reason *',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ] else if (_selectedAction == 'CHANGE_LIMIT') ...[
                    TextField(
                      controller: _limitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'New Borrowing Limit *',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ] else if (_selectedAction == 'CHANGE_TYPE') ...[
                    Builder(
                      builder: (context) {
                        final availableTypes = state.filterOptions.memberTypes.isNotEmpty
                            ? state.filterOptions.memberTypes
                            : ['Student', 'Teacher', 'Staff', 'Librarian', 'Special / Research'];
                        final effectiveType = availableTypes.contains(_targetMembershipType)
                            ? _targetMembershipType
                            : availableTypes.first;

                        return DropdownButtonFormField<String>(
                          value: effectiveType,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          decoration: InputDecoration(
                            labelText: 'New Membership Type',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          items: availableTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _targetMembershipType = val);
                          },
                        );
                      },
                    ),
                  ],
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
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text('Execute for $selectedCount Members', style: const TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isActionLoading ? null : _submitBulkAction,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBulkAction() async {
    final Map<String, dynamic> params = {};

    if (_selectedAction == 'SUSPEND') {
      params['reason'] = _reasonCtrl.text.trim();
    } else if (_selectedAction == 'CHANGE_LIMIT') {
      params['borrowing_limit'] = int.tryParse(_limitCtrl.text.trim()) ?? 3;
    } else if (_selectedAction == 'CHANGE_TYPE') {
      params['membership_type'] = _targetMembershipType;
    }

    final success = await ref.read(memberProvider.notifier).executeBulkAction(
      _selectedAction,
      params: params,
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
