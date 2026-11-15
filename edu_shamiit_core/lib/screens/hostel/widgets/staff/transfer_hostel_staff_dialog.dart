import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class TransferHostelStaffDialog extends ConsumerStatefulWidget {
  final HostelStaffRosterItem staff;

  const TransferHostelStaffDialog({super.key, required this.staff});

  @override
  ConsumerState<TransferHostelStaffDialog> createState() => _TransferHostelStaffDialogState();
}

class _TransferHostelStaffDialogState extends ConsumerState<TransferHostelStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _newHostelId;
  final _areaController = TextEditingController(text: 'Overall');
  final _reasonController = TextEditingController(text: 'Administrative Operational Transfer');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _areaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final buildings = state.structureTree;

    // Filter to other hostels
    final destinationHostels = buildings.where((b) => b.id != widget.staff.hostelId).toList();
    if (_newHostelId == null && destinationHostels.isNotEmpty) {
      _newHostelId = destinationHostels.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swap_horiz, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transfer Staff - ${widget.staff.name}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Current: ${widget.staff.hostelName} (${widget.staff.assignedArea})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Destination Hostel
                const Text('Destination Hostel *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _newHostelId,
                      isExpanded: true,
                      items: (destinationHostels.isNotEmpty ? destinationHostels : buildings).map((b) {
                        return DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _newHostelId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // New Area
                const Text('New Assigned Area *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _areaController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1st Floor, Main Gate, Overall',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Reason
                const Text('Transfer Reason / Notes *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitTransfer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Transfer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitTransfer() async {
    if (_newHostelId == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final payload = {
      'assignment_id': widget.staff.assignmentId,
      'new_hostel_id': _newHostelId,
      'new_area_text': _areaController.text.trim(),
      'reason': _reasonController.text.trim(),
    };

    final success = await ref.read(hostelProvider.notifier).transferStaff(
      widget.staff.assignmentId,
      payload,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop();
    }
  }
}
