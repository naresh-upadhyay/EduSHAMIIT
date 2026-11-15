import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import 'visitor_registration_dialog.dart';

class VisitorCheckInDialog extends ConsumerStatefulWidget {
  final VisitorItem? visit;

  const VisitorCheckInDialog({super.key, this.visit});

  @override
  ConsumerState<VisitorCheckInDialog> createState() => _VisitorCheckInDialogState();
}

class _VisitorCheckInDialogState extends ConsumerState<VisitorCheckInDialog> {
  final _remarksCtrl = TextEditingController();
  String _selectedGate = 'Main Gate';
  bool _idVerified = true;
  bool _isSubmitting = false;

  final List<String> _gates = [
    'Main Gate',
    'North Gate',
    'South Gate',
    'Reception Desk',
    'Hostel Gate',
  ];

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCheckIn() async {
    if (widget.visit == null) return;
    setState(() => _isSubmitting = true);

    final ok = await ref.read(visitorsProvider.notifier).checkInVisit(
          widget.visit!.id,
          entryLocation: _selectedGate,
          remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.visit == null) {
      // Quick walk-in choice: open registration dialog with instant check-in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => const VisitorRegistrationDialog(initialInstantCheckIn: true),
        );
      });
      return const SizedBox.shrink();
    }

    final visit = widget.visit!;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 520;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 480.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 24, vertical: 16),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        padding: EdgeInsets.all(isNarrow ? 16 : 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.login, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check-In Confirmation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Authorize campus entry for ${visit.visitorName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),

            // Visit Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _infoRow('Visitor Name', visit.visitorName, isDark, isBold: true),
                  const SizedBox(height: 6),
                  _infoRow('Category & Purpose', '${visit.visitorType} • ${visit.purpose}', isDark),
                  const SizedBox(height: 6),
                  _infoRow('Destination / Host', '${visit.location} • ${visit.hostName}', isDark),
                  const SizedBox(height: 6),
                  _infoRow('Expected Duration', 'Until ${visit.expectedOut}', isDark),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Check-in Gate
            DropdownButtonFormField<String>(
              initialValue: _selectedGate,
              decoration: const InputDecoration(
                labelText: 'Entry Checkpoint / Gate *',
                prefixIcon: Icon(Icons.door_sliding_outlined, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _gates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedGate = val);
              },
            ),
            const SizedBox(height: 14),

            // Verification Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _idVerified,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Identity verified against physical ID document',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              onChanged: (val) => setState(() => _idVerified = val ?? true),
            ),
            const SizedBox(height: 10),

            // Remarks
            TextFormField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Entry Remarks / Gate Notes',
                hintText: 'e.g., Accompanied by 1 guest, badge #14 issued',
                prefixIcon: Icon(Icons.notes, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_isSubmitting ? 'Checking In...' : 'Confirm Check-In'),
                  onPressed: _isSubmitting ? null : _submitCheckIn,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
