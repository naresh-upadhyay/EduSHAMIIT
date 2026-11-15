import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/work_management_provider.dart';

class CompleteSprintDialog extends ConsumerStatefulWidget {
  final String sprintId;
  final String sprintName;
  final int completedCount;
  final int incompleteCount;

  const CompleteSprintDialog({
    super.key,
    required this.sprintId,
    required this.sprintName,
    required this.completedCount,
    required this.incompleteCount,
  });

  @override
  ConsumerState<CompleteSprintDialog> createState() => _CompleteSprintDialogState();
}

class _CompleteSprintDialogState extends ConsumerState<CompleteSprintDialog> {
  final TextEditingController _notesController = TextEditingController();
  String _destination = 'NEXT_SPRINT';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final notifier = ref.read(workSprintDashboardProvider.notifier);

    final success = await notifier.completeSprint(
      widget.sprintId,
      moveIncompleteToSprintId: _destination == 'NEXT_SPRINT' ? '332ae580-759a-424f-a647-c3ad9155f6c3' : null,
      notes: _notesController.text.trim(),
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete sprint')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Complete ${widget.sprintName}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.completedCount} work items completed',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.incompleteCount} work items remain open / in progress',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (widget.incompleteCount > 0) ...[
                Text(
                  'Move incomplete work items to:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                RadioListTile<String>(
                  title: const Text('Next Planned Sprint (Sprint 9)', style: TextStyle(fontSize: 12.5)),
                  value: 'NEXT_SPRINT',
                  groupValue: _destination,
                  onChanged: (v) => setState(() => _destination = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text('Product Backlog', style: TextStyle(fontSize: 12.5)),
                  value: 'BACKLOG',
                  groupValue: _destination,
                  onChanged: (v) => setState(() => _destination = v!),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
              ],

              Text(
                'Retrospective Notes / Sprint Summary',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Summary of sprint achievements and learnings...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
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
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Complete Sprint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
