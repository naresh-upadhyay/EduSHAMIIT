import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';

class RestrictionUpdateDialog extends ConsumerStatefulWidget {
  final BlacklistedVisitorItem restriction;

  const RestrictionUpdateDialog({super.key, required this.restriction});

  @override
  ConsumerState<RestrictionUpdateDialog> createState() => _RestrictionUpdateDialogState();
}

class _RestrictionUpdateDialogState extends ConsumerState<RestrictionUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _reasonCtrl;
  late TextEditingController _scopeCtrl;
  late TextEditingController _validTillCtrl;
  late TextEditingController _remarksCtrl;
  late bool _isPermanent;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _reasonCtrl = TextEditingController(text: widget.restriction.reasonCategory);
    _scopeCtrl = TextEditingController(text: widget.restriction.scopeName);
    _remarksCtrl = TextEditingController(text: widget.restriction.remarks ?? '');
    
    final validText = widget.restriction.validTillText.trim();
    _isPermanent = widget.restriction.isPermanent || validText.toLowerCase() == 'permanent';

    if (_isPermanent) {
      _validTillCtrl = TextEditingController(text: 'Permanent');
      _selectedDate = null;
    } else {
      DateTime? parsed;
      try {
        parsed = DateTime.tryParse(validText);
      } catch (_) {}
      _selectedDate = parsed ?? DateTime.now().add(const Duration(days: 30));
      final text = validText.isNotEmpty && validText.toLowerCase() != 'permanent'
          ? validText
          : _formatDate(_selectedDate!);
      _validTillCtrl = TextEditingController(text: text);
    }
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final mon = months[dt.month - 1];
    final yr = dt.year.toString();
    return '$day $mon $yr';
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Select Valid Till Date',
      confirmText: 'Select',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isPermanent = false;
        _validTillCtrl.text = _formatDate(picked);
      });
    }
  }

  void _onPermanentToggle(bool? val) {
    setState(() {
      _isPermanent = val ?? true;
      if (_isPermanent) {
        _validTillCtrl.text = 'Permanent';
      } else {
        _selectedDate ??= DateTime.now().add(const Duration(days: 30));
        _validTillCtrl.text = _formatDate(_selectedDate!);
      }
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _scopeCtrl.dispose();
    _validTillCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final String validTillText = _isPermanent ? 'Permanent' : _validTillCtrl.text.trim();
    final String validTillValue = _isPermanent
        ? 'Permanent'
        : (_selectedDate != null ? _selectedDate!.toIso8601String() : validTillText);

    final payload = {
      'reason_category': _reasonCtrl.text.trim(),
      'scope_name': _scopeCtrl.text.trim(),
      'valid_till': validTillValue,
      'valid_till_text': validTillText,
      'is_permanent': _isPermanent,
      'remarks': _remarksCtrl.text.trim(),
    };

    final ok = await ref.read(visitorsProvider.notifier).updateRestriction(
      widget.restriction.id,
      payload,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 540;
    final dialogWidth = math.min(screenWidth * 0.95, 520.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 24, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenHeight * 0.90,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Restriction Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${widget.restriction.visitorName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

                if (isNarrow) ...[
                  TextFormField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Block Reason *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Reason required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _scopeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Restricted Location(s) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Location required' : null,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _reasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Block Reason *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Reason required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _scopeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Restricted Location(s) *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Location required' : null,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                if (isNarrow) ...[
                  Row(
                    children: [
                      Checkbox(
                        value: _isPermanent,
                        onChanged: _onPermanentToggle,
                      ),
                      const Text('Permanent Restriction', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (!_isPermanent) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _validTillCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(context),
                      decoration: InputDecoration(
                        labelText: 'Valid Till Date *',
                        hintText: 'Select valid till date...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF2563EB)),
                          onPressed: () => _pickDate(context),
                        ),
                      ),
                      validator: (v) {
                        if (!_isPermanent && (v == null || v.trim().isEmpty || v.trim().toLowerCase() == 'permanent')) {
                          return 'Please select a valid date';
                        }
                        return null;
                      },
                    ),
                  ],
                ] else ...[
                  Row(
                    children: [
                      Checkbox(
                        value: _isPermanent,
                        onChanged: _onPermanentToggle,
                      ),
                      const Text('Permanent Restriction', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      if (!_isPermanent)
                        Expanded(
                          child: TextFormField(
                            controller: _validTillCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(context),
                            decoration: InputDecoration(
                              labelText: 'Valid Till Date *',
                              hintText: 'Select valid till date...',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF2563EB)),
                                onPressed: () => _pickDate(context),
                              ),
                            ),
                            validator: (v) {
                              if (!_isPermanent && (v == null || v.trim().isEmpty || v.trim().toLowerCase() == 'permanent')) {
                                return 'Please select a valid date';
                              }
                              return null;
                            },
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                TextFormField(
                  controller: _remarksCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Incident Details',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Details'),
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
}
