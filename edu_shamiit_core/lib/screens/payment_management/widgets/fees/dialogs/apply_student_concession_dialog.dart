import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class ApplyStudentConcessionDialog extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String invoiceId;

  const ApplyStudentConcessionDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.invoiceId,
  });

  @override
  ConsumerState<ApplyStudentConcessionDialog> createState() => _ApplyStudentConcessionDialogState();
}

class _ApplyStudentConcessionDialogState extends ConsumerState<ApplyStudentConcessionDialog> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  final TextEditingController _reasonController = TextEditingController();
  String _concessionType = 'Academic Merit Scholarship';
  bool _submitting = false;

  List<PaymentLookupItem> _concessionTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final types = await PaymentLookupHelper.instance.getActiveLookup('STUDENT_FEE_CONCESSION_TYPE');
    if (mounted) {
      setState(() {
        _concessionTypes = types;
        if (types.isNotEmpty) _concessionType = types.first.label;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_offer_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Apply Fee Concession', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text(widget.studentName, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              Text('Concession / Scholarship Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Builder(
                  builder: (context) {
                    final Map<String, String> concMap = {};
                    for (final c in _concessionTypes) {
                      if (c.label.isNotEmpty) concMap[c.label] = c.label;
                    }
                    if (concMap.isEmpty) {
                      concMap['Academic Merit Scholarship'] = 'Academic Merit Scholarship';
                      concMap['Sibling Concession'] = 'Sibling Concession';
                      concMap['Staff Ward Concession'] = 'Staff Ward Concession';
                      concMap['Sports Excellence Quota'] = 'Sports Excellence Quota';
                    }
                    String effectiveType = _concessionType;
                    if (!concMap.containsKey(effectiveType)) {
                      final match = concMap.keys.firstWhere(
                        (k) => k.toLowerCase() == effectiveType.toLowerCase(),
                        orElse: () => '',
                      );
                      if (match.isNotEmpty) {
                        effectiveType = match;
                      } else {
                        concMap[effectiveType] = effectiveType;
                      }
                    }

                    return DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        key: ValueKey('concession_type_$effectiveType'),
                        value: effectiveType,
                        isExpanded: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: concMap.entries.map((c) => DropdownMenuItem(value: c.key, child: Text(c.value))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _concessionType = val);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Text('Concession Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              Text('Approval Reason & Justification', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'e.g. 95% aggregate merit board waiver',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Apply Concession', style: TextStyle(fontWeight: FontWeight.w600)),
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
    final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    setState(() => _submitting = true);
    final ok = await PaymentManagementApiService.instance.applyStudentConcession({
      'student_id': widget.studentId,
      'invoice_id': widget.invoiceId.trim().isEmpty ? null : widget.invoiceId.trim(),
      'concession_type': _concessionType,
      'amount': amt,
      'reason': _reasonController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee concession applied successfully!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
