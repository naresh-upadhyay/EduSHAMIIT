import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/member_models.dart';
import '../../providers/member_provider.dart';

class RenewMembershipDialog extends ConsumerStatefulWidget {
  final LibraryMemberModel member;
  const RenewMembershipDialog({super.key, required this.member});

  @override
  ConsumerState<RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends ConsumerState<RenewMembershipDialog> {
  String _selectedPreset = '1_year';
  late DateTime _newExpiryDate;
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentExpiry = widget.member.membershipExpiryDate ?? DateTime.now();
    _newExpiryDate = DateTime(currentExpiry.year + 1, currentExpiry.month, currentExpiry.day);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onPresetChanged(String preset) {
    final currentExpiry = widget.member.membershipExpiryDate ?? DateTime.now();
    DateTime calculated;

    if (preset == '6_months') {
      calculated = DateTime(currentExpiry.year, currentExpiry.month + 6, currentExpiry.day);
    } else if (preset == '1_year') {
      calculated = DateTime(currentExpiry.year + 1, currentExpiry.month, currentExpiry.day);
    } else if (preset == '2_years') {
      calculated = DateTime(currentExpiry.year + 2, currentExpiry.month, currentExpiry.day);
    } else {
      calculated = _newExpiryDate;
    }

    setState(() {
      _selectedPreset = preset;
      _newExpiryDate = calculated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');
    final currentExpiryStr = widget.member.membershipExpiryDate != null
        ? dateFormat.format(widget.member.membershipExpiryDate!)
        : 'Not Set';

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
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.autorenew_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Renew Library Membership',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Member: ${widget.member.memberName} (${widget.member.memberCode})',
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
                  // Expiry Comparison Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Current Expiry',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentExpiryStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 20),
                        Column(
                          children: [
                            const Text(
                              'New Expiry',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(_newExpiryDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Renewal Presets Selector
                  const Text(
                    'Select Renewal Period',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPresetChip('6 Months', '6_months', isDark),
                      const SizedBox(width: 8),
                      _buildPresetChip('1 Year', '1_year', isDark),
                      const SizedBox(width: 8),
                      _buildPresetChip('2 Years', '2_years', isDark),
                      const SizedBox(width: 8),
                      _buildPresetChip('Custom', 'custom', isDark),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // If custom, allow picking exact date
                  if (_selectedPreset == 'custom') ...[
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _newExpiryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _newExpiryDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Custom Expiry Date: ${dateFormat.format(_newExpiryDate)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF6366F1)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Notes / Reason
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Renewal Notes / Remarks (Optional)',
                      hintText: 'e.g. Annual library subscription renewal fee received.',
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
                        : const Icon(Icons.autorenew_rounded, size: 17),
                    label: const Text('Confirm Renewal', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isActionLoading ? null : _submitRenewal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String code, bool isDark) {
    final isSelected = _selectedPreset == code;

    return Expanded(
      child: InkWell(
        onTap: () => _onPresetChanged(code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF10B981)
                  : (isDark ? Colors.white : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRenewal() async {
    final success = await ref.read(memberProvider.notifier).renewMembership(
      memberId: widget.member.id,
      newExpiryDate: _newExpiryDate,
      renewalPeriod: _selectedPreset,
      notes: _notesCtrl.text.trim(),
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
