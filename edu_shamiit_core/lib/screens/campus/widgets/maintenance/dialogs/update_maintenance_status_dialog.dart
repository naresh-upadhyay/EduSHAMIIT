import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';

class UpdateMaintenanceStatusDialog extends ConsumerStatefulWidget {
  final MaintenanceRequestItem request;

  const UpdateMaintenanceStatusDialog({super.key, required this.request});

  @override
  ConsumerState<UpdateMaintenanceStatusDialog> createState() => _UpdateMaintenanceStatusDialogState();
}

class _UpdateMaintenanceStatusDialogState extends ConsumerState<UpdateMaintenanceStatusDialog> {
  late String _status;
  final _remarksController = TextEditingController();
  final _costController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.request.status;
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final cost = double.tryParse(_costController.text.trim());

    final success = await ref.read(maintenanceProvider.notifier).updateStatus(
      widget.request.id,
      _status,
      remarks: _remarksController.text.trim(),
      resolutionNotes: _status == 'Resolved' || _status == 'Closed' ? _remarksController.text.trim() : null,
      actualCost: cost,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $_status!'), backgroundColor: const Color(0xFF16A34A)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status.'), backgroundColor: Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = math.min(460.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Update Status - ${widget.request.requestCode}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'New Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                dropdownColor: bg,
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                  DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'On Hold', child: Text('On Hold')),
                  DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _remarksController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Remarks / Resolution Notes',
                  hintText: 'Add inspection or repair notes...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 12),

              if (_status == 'Resolved' || _status == 'Closed') ...[
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Actual Repair Cost (₹)',
                    hintText: 'e.g. 1200.00',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
