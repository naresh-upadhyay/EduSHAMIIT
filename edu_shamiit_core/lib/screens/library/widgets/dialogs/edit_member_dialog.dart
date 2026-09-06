import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/member_models.dart';
import '../../providers/member_provider.dart';

class EditMemberDialog extends ConsumerStatefulWidget {
  final LibraryMemberModel member;
  const EditMemberDialog({super.key, required this.member});

  @override
  ConsumerState<EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<EditMemberDialog> {
  late TextEditingController _borrowingLimitCtrl;
  late TextEditingController _maxDaysCtrl;
  late TextEditingController _notesCtrl;

  late String _membershipType;
  late DateTime _expiryDate;
  late bool _renewalAllowed;
  late int _maxRenewals;
  late String _status;

  @override
  void initState() {
    super.initState();
    _borrowingLimitCtrl = TextEditingController(text: '${widget.member.borrowingLimit}');
    _maxDaysCtrl = TextEditingController(text: '${widget.member.maxIssueDurationDays}');
    _notesCtrl = TextEditingController(text: widget.member.notes ?? '');

    _membershipType = widget.member.membershipType;
    _expiryDate = widget.member.membershipExpiryDate ?? DateTime.now().add(const Duration(days: 365));
    _renewalAllowed = widget.member.renewalAllowed;
    _maxRenewals = widget.member.maxRenewals;
    _status = widget.member.status;
  }

  @override
  void dispose() {
    _borrowingLimitCtrl.dispose();
    _maxDaysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Membership — ${widget.member.memberName}',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Member ID: ${widget.member.memberCode}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
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

            // Form Body
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Read-Only Identity Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          child: Text(
                            widget.member.memberName.isNotEmpty ? widget.member.memberName[0].toUpperCase() : 'M',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.member.memberName} (${widget.member.role ?? "Patron"})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${widget.member.classOrDepartment} • ${widget.member.email ?? ""}',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Membership Type & Status
                  Builder(
                    builder: (context) {
                      final memberState = ref.watch(memberProvider);
                      final availableMemberTypes = memberState.filterOptions.memberTypes.isNotEmpty
                          ? memberState.filterOptions.memberTypes
                          : ['Student', 'Teacher', 'Staff', 'Librarian', 'Special / Research'];
                      final effectiveType = availableMemberTypes.contains(_membershipType)
                          ? _membershipType
                          : (availableMemberTypes.isNotEmpty ? availableMemberTypes.first : _membershipType);

                      return Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Membership Type',
                              child: DropdownButtonFormField<String>(
                                value: effectiveType,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: _inputDecoration(isDark),
                                items: availableMemberTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _membershipType = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: 'Status',
                              child: DropdownButtonFormField<String>(
                                value: _status,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                decoration: _inputDecoration(isDark),
                                items: const [
                                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                                  DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
                                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expired')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _status = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Limits & Expiry
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: 'Max Books Allowed',
                          child: TextField(
                            controller: _borrowingLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(isDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormField(
                          label: 'Membership Expiry Date',
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _expiryDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) setState(() => _expiryDate = picked);
                            },
                            child: InputDecorator(
                              decoration: _inputDecoration(isDark),
                              child: Text(dateFormat.format(_expiryDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  _buildFormField(
                    label: 'Notes / Remarks',
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration(isDark, hint: 'Membership notes...'),
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
                        : const Icon(Icons.save_rounded, size: 17),
                    label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isActionLoading ? null : _submitUpdateMember,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Future<void> _submitUpdateMember() async {
    final limit = int.tryParse(_borrowingLimitCtrl.text.trim()) ?? 3;
    final maxDays = int.tryParse(_maxDaysCtrl.text.trim()) ?? 14;

    final payload = {
      'membership_type': _membershipType,
      'membership_expiry_date': _expiryDate.toIso8601String().split('T').first,
      'borrowing_limit': limit,
      'max_issue_duration_days': maxDays,
      'renewal_allowed': _renewalAllowed,
      'max_renewals': _maxRenewals,
      'status': _status,
      'notes': _notesCtrl.text.trim(),
    };

    final success = await ref.read(memberProvider.notifier).updateMember(widget.member.id, payload);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
