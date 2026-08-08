import 'package:flutter/material.dart';

class RecurrenceScopeDialog extends StatefulWidget {
  final String actionTitle; // e.g. "Edit Recurring Schedule" or "Delete Recurring Schedule"
  final Function(String scope) onScopeSelected;

  const RecurrenceScopeDialog({
    super.key,
    required this.actionTitle,
    required this.onScopeSelected,
  });

  @override
  State<RecurrenceScopeDialog> createState() => _RecurrenceScopeDialogState();
}

class _RecurrenceScopeDialogState extends State<RecurrenceScopeDialog> {
  String _selectedScope = 'this_event';

  @override
  Widget build(BuildContext context) {
    final isDelete = widget.actionTitle.toLowerCase().contains('delete');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDelete
                        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                        : const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDelete ? Icons.delete_forever_rounded : Icons.repeat_rounded,
                    color: isDelete ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.actionTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'This is a recurring event series. Which occurrences would you like to affect?',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),

            // Option 1: This event only
            _buildOptionTile(
              scope: 'this_event',
              title: 'This event only',
              subtitle: isDelete
                  ? 'Delete only this specific occurrence'
                  : 'Modify only this single specific occurrence',
              icon: Icons.event_available_rounded,
            ),
            const SizedBox(height: 10),

            // Option 2: This and following events
            _buildOptionTile(
              scope: 'following_events',
              title: 'This and following events',
              subtitle: isDelete
                  ? 'Delete this occurrence and all future occurrences'
                  : 'Modify this instance and all future occurrences',
              icon: Icons.skip_next_rounded,
            ),
            const SizedBox(height: 10),

            // Option 3: All events in the series
            _buildOptionTile(
              scope: 'entire_series',
              title: 'All events in the series',
              subtitle: isDelete
                  ? 'Delete all occurrences across the entire recurring series'
                  : 'Apply changes to the entire recurring series',
              icon: Icons.repeat_on_rounded,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onScopeSelected(_selectedScope);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDelete ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isDelete ? 'Delete' : 'OK',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String scope,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedScope == scope;

    return InkWell(
      onTap: () {
        setState(() => _selectedScope = scope);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                  width: isSelected ? 6 : 2,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
