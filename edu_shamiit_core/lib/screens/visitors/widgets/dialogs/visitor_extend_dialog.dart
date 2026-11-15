import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';

class VisitorExtendDialog extends ConsumerStatefulWidget {
  final String visitId;
  final String visitorName;

  VisitorExtendDialog({
    super.key,
    String? visitId,
    String? visitorName,
    VisitorItem? visit,
  })  : visitId = visitId ?? visit?.id ?? '',
        visitorName = visitorName ?? visit?.visitorName ?? '';

  @override
  ConsumerState<VisitorExtendDialog> createState() => _VisitorExtendDialogState();
}

class _VisitorExtendDialogState extends ConsumerState<VisitorExtendDialog> {
  int _selectedMinutes = 60;
  final _reasonController = TextEditingController(text: 'Meeting prolonged with host');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 480;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 440.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 24, vertical: 16),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Extend Visit Duration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Extending authorized departure for ${widget.visitorName}.',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),

            // Time Selector chips
            const Text('Extension Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [30, 60, 90, 120].map((mins) {
                final isSelected = _selectedMinutes == mins;
                return ChoiceChip(
                  label: Text('$mins mins'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedMinutes = mins);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Reason
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Extension',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Extension', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final notifier = ref.read(visitorsProvider.notifier);
    final ok = await notifier.extendVisit(
      widget.visitId,
      extensionMinutes: _selectedMinutes,
      reason: _reasonController.text.trim(),
    );
    setState(() => _isSubmitting = false);
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }
}
