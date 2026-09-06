import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/request_models.dart';
import '../../providers/request_provider.dart';

class ProcessRequestDialog extends ConsumerStatefulWidget {
  final LibraryRequestItem request;
  final String? initialAction;

  const ProcessRequestDialog({
    Key? key,
    required this.request,
    this.initialAction,
  }) : super(key: key);

  @override
  ConsumerState<ProcessRequestDialog> createState() => _ProcessRequestDialogState();
}

class _ProcessRequestDialogState extends ConsumerState<ProcessRequestDialog> {
  late String _action;
  late String _targetStatus;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _selectedLibrarianId;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _action = widget.initialAction ?? _getDefaultAction(widget.request.status);
    _targetStatus = _getDefaultTargetStatus(widget.request.status, _action);
  }

  String _getDefaultAction(String currentStatus) {
    switch (currentStatus.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        return 'TRANSITION_ACTIVE';
      case 'ACTIVE':
        return 'TRANSITION_IN_PROGRESS';
      case 'IN_PROGRESS':
        return 'TRANSITION_RESOLVED';
      case 'RESOLVED':
        return 'TRANSITION_COMPLETED';
      default:
        return 'ADD_COMMENT';
    }
  }

  String _getDefaultTargetStatus(String currentStatus, String action) {
    if (action == 'REJECT') return 'REJECTED';
    if (action == 'CANCEL') return 'CANCELED';
    if (action == 'TRANSITION_ACTIVE') return 'ACTIVE';
    if (action == 'TRANSITION_IN_PROGRESS') return 'IN_PROGRESS';
    if (action == 'TRANSITION_RESOLVED') return 'RESOLVED';
    if (action == 'TRANSITION_COMPLETED') return 'COMPLETED';
    return 'ACTIVE';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestProvider);
    final options = state.options;


    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Request info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Process ${widget.request.requestNumber}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.request.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 18),

            // Action Selector Dropdown
            const Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _action,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'TRANSITION_ACTIVE', child: Text('Accept & Mark Active')),
                    DropdownMenuItem(value: 'TRANSITION_IN_PROGRESS', child: Text('Move to In Progress (Procuring / Processing)')),
                    DropdownMenuItem(value: 'TRANSITION_RESOLVED', child: Text('Mark Resolved (Ready on Hold Shelf)')),
                    DropdownMenuItem(value: 'TRANSITION_COMPLETED', child: Text('Mark Completed (Issued / Delivered)')),
                    DropdownMenuItem(value: 'ASSIGN_LIBRARIAN', child: Text('Assign to Librarian')),
                    DropdownMenuItem(value: 'REJECT', child: Text('Reject Request', style: TextStyle(color: Color(0xFFDC2626)))),
                    DropdownMenuItem(value: 'CANCEL', child: Text('Cancel Request')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _action = val;
                        _targetStatus = _getDefaultTargetStatus(widget.request.status, val);
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Assign Librarian Selector
            if (_action == 'ASSIGN_LIBRARIAN') ...[
              const Text('Select Librarian *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLibrarianId,
                    hint: const Text('Choose a staff member', style: TextStyle(fontSize: 13)),
                    isExpanded: true,
                    items: options.librarians.map((lib) {
                      return DropdownMenuItem<String>(
                        value: lib['id']?.toString(),
                        child: Text('${lib['full_name']} (${lib['role']})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedLibrarianId = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Mandatory Rejection Reason
            if (_action == 'REJECT') ...[
              const Text('Rejection Reason *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Duplicate request, budget cap exceeded, or out of print',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFFEF2F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFECACA))),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Optional Comment / Audit Note
            const Text('Comment / Note (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _commentController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Add an audit note or reason for this action...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // Footer Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _executeAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _action == 'REJECT' ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_action == 'REJECT' ? 'Confirm Rejection' : 'Update Status', style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeAction() async {
    final notifier = ref.read(requestProvider.notifier);

    if (_action == 'REJECT' && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a rejection reason'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    if (_action == 'ASSIGN_LIBRARIAN' && _selectedLibrarianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a librarian'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (_action == 'ASSIGN_LIBRARIAN') {
        await notifier.assignRequest(
          requestId: widget.request.id,
          assignedTo: _selectedLibrarianId!,
          notes: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        );
      } else {
        await notifier.transitionStatus(
          requestId: widget.request.id,
          toStatus: _targetStatus,
          reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
          comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status updated successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }
}
