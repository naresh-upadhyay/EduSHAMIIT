import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/hostel_complaint_models.dart';
import '../../../providers/hostel_provider.dart';

class UpdateComplaintStatusDialog extends ConsumerStatefulWidget {
  final HostelComplaintItem complaint;
  final String? initialStatus;

  const UpdateComplaintStatusDialog({
    super.key,
    required this.complaint,
    this.initialStatus,
  });

  @override
  ConsumerState<UpdateComplaintStatusDialog> createState() => _UpdateComplaintStatusDialogState();
}

class _UpdateComplaintStatusDialogState extends ConsumerState<UpdateComplaintStatusDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _targetStatus;
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _partsController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  String _resolutionType = 'Permanent Repair';
  bool _isSubmitting = false;

  static const List<String> _statuses = [
    'ACTIVE',
    'IN_PROGRESS',
    'ON_HOLD',
    'RESOLVED',
    'COMPLETED',
    'REJECTED',
    'CANCELED',
  ];

  static const List<String> _resolutionTypes = [
    'Permanent Repair',
    'Temporary Fix',
    'Part Replaced',
    'Cleaned / Serviced',
    'No Defect Found',
    'Vendor Handled',
  ];

  @override
  void initState() {
    super.initState();
    _targetStatus = widget.initialStatus ?? _getNextSuggestedStatus(widget.complaint.status);
    if (_targetStatus == 'RESOLVED' && widget.complaint.resolutionSummary != null) {
      _summaryController.text = widget.complaint.resolutionSummary!;
    }
  }

  String _getNextSuggestedStatus(String current) {
    switch (current.toUpperCase()) {
      case 'OPEN':
      case 'NEW':
        return 'ACTIVE';
      case 'ACTIVE':
        return 'IN_PROGRESS';
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
      case 'PENDING':
        return 'RESOLVED';
      case 'RESOLVED':
        return 'COMPLETED';
      default:
        return 'IN_PROGRESS';
    }
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _reasonController.dispose();
    _partsController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final notifier = ref.read(hostelProvider.notifier);
    bool success = false;

    if (_targetStatus == 'RESOLVED') {
      List<dynamic>? parts;
      if (_partsController.text.trim().isNotEmpty) {
        parts = _partsController.text.split(',').map((p) => {'item_name': p.trim(), 'quantity': 1}).toList();
      }
      final double? cost = double.tryParse(_costController.text.trim());

      success = await notifier.resolveComplaint(
        widget.complaint.id,
        _summaryController.text.trim(),
        type: _resolutionType,
        parts: parts,
        cost: cost,
        equipmentStatus: 'WORKING',
      );
    } else {
      success = await notifier.updateComplaintStatus(
        widget.complaint.id,
        _targetStatus,
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final isResolving = _targetStatus == 'RESOLVED';
    final isRejecting = _targetStatus == 'REJECTED';
    final isCanceling = _targetStatus == 'CANCELED' || _targetStatus == 'ON_HOLD';

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.95 : 540,
          maxHeight: screenHeight * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Status: ${widget.complaint.complaintNumber}',
                          style: TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        Text(
                          widget.complaint.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Status selector
                    Text('Select Target Status *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _targetStatus,
                      isExpanded: true,
                      dropdownColor: cardBg,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      ),
                      items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _targetStatus = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // If Resolving: Resolution Summary & Work details
                    if (isResolving) ...[
                      Text('Resolution Summary *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _summaryController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Inspected bathroom faucet, replaced the rubber washer and tightened connector pipe. Water flow verified.',
                          hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter resolution summary' : null,
                      ),
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resolution Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            const SizedBox(height: 4),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _resolutionType,
                              isExpanded: true,
                              dropdownColor: cardBg,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: fieldBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              ),
                              items: _resolutionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _resolutionType = v!),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Estimated Cost (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                filled: true,
                                fillColor: fieldBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Resolution Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 4),
                                  AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _resolutionType,
                                    isExpanded: true,
                                    dropdownColor: cardBg,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                    ),
                                    items: _resolutionTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _resolutionType = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Estimated Cost (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _costController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      filled: true,
                                      fillColor: fieldBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _partsController,
                        style: TextStyle(fontSize: 12, color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Parts / Materials Used (Optional)',
                          hintText: 'Comma-separated, e.g. Rubber Gasket, Teflon Tape',
                          hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                      ),
                    ] else if (isRejecting || isCanceling) ...[
                      Text(
                        isRejecting ? 'Rejection Reason *' : 'Reason / Note *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: isRejecting
                              ? 'e.g. Duplicate complaint already under active repair (HC-2024-001).'
                              : 'Please provide reason for status change...',
                          hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify reason' : null,
                      ),
                    ] else ...[
                      Text('Progress Note / Remark (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add an update note for this status change...',
                          hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: borderColor),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isResolving ? Icons.verified_rounded : Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Saving...' : (isResolving ? 'Mark Resolved' : 'Update Status'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isResolving ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
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
