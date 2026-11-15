import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/work_management_provider.dart';

class MoveSprintItemsDialog extends ConsumerStatefulWidget {
  final String currentSprintId;
  final List<String> itemIds;
  final String itemLabel;

  const MoveSprintItemsDialog({
    super.key,
    required this.currentSprintId,
    required this.itemIds,
    this.itemLabel = 'selected work item(s)',
  });

  @override
  ConsumerState<MoveSprintItemsDialog> createState() => _MoveSprintItemsDialogState();
}

class _MoveSprintItemsDialogState extends ConsumerState<MoveSprintItemsDialog> {
  String _selectedTarget = '332ae580-759a-424f-a647-c3ad9155f6c3'; // Sprint 9
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sprintState = ref.watch(workSprintDashboardProvider);
    final upcoming = sprintState.upcomingSprints;

    final targetOptions = [
      ...upcoming.map((s) => {
            'id': s['id']?.toString() ?? '',
            'name': '${s['name']} (${s['status']})',
          }),
      {'id': 'BACKLOG', 'name': 'Product Backlog (Unassign)'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Move Work Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Text(
                'Move ${widget.itemIds.length} ${widget.itemLabel} to:',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              ...targetOptions.map((opt) {
                final id = opt['id'] ?? '';
                final name = opt['name'] ?? '';

                return RadioListTile<String>(
                  value: id,
                  groupValue: _selectedTarget,
                  onChanged: (v) => setState(() => _selectedTarget = v!),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            setState(() => _isSubmitting = true);
                            final notifier = ref.read(workSprintDashboardProvider.notifier);

                            bool success = false;
                            if (_selectedTarget == 'BACKLOG') {
                              for (final itemId in widget.itemIds) {
                                success = await notifier.removeItemFromSprint(widget.currentSprintId, itemId);
                              }
                            } else {
                              success = await notifier.moveItemsToSprint(
                                widget.currentSprintId,
                                _selectedTarget,
                                widget.itemIds,
                              );
                            }

                            if (mounted) {
                              if (success) {
                                Navigator.of(context).pop(true);
                              } else {
                                setState(() => _isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to move items')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Confirm Move', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
