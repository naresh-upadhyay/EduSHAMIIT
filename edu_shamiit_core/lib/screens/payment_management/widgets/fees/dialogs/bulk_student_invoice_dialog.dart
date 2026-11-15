import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class BulkStudentInvoiceDialog extends ConsumerStatefulWidget {
  const BulkStudentInvoiceDialog({super.key});

  @override
  ConsumerState<BulkStudentInvoiceDialog> createState() => _BulkStudentInvoiceDialogState();
}

class _BulkStudentInvoiceDialogState extends ConsumerState<BulkStudentInvoiceDialog> {
  String _selectedClass = 'All Classes';
  final String _title = 'Monthly Tuition & Activities Fee';
  final String _feeType = 'Tuition Fee';
  final String _feePlan = 'Monthly';
  final TextEditingController _amountController = TextEditingController(text: '4500');
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
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
          maxWidth: 480,
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
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.dynamic_feed_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Bulk Generate Invoices',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              Text('Target Class Cohort', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'All Classes', child: Text('All Enrolled Students (Entire School)')),
                      DropdownMenuItem(value: 'Class 5', child: Text('Class 5')),
                      DropdownMenuItem(value: 'Class 9', child: Text('Class 9')),
                      DropdownMenuItem(value: 'Class 10', child: Text('Class 10')),
                      DropdownMenuItem(value: 'Class 11', child: Text('Class 11')),
                      DropdownMenuItem(value: 'Class 12', child: Text('Class 12')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedClass = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text('Default Amount Per Student (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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

              Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _dueDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(_dueDate), style: const TextStyle(fontSize: 13)),
                      const Icon(Icons.calendar_today_rounded, size: 16),
                    ],
                  ),
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
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Execute Bulk Invoicing', style: TextStyle(fontWeight: FontWeight.w600)),
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
    final ok = await PaymentManagementApiService.instance.bulkGenerateStudentInvoices({
      'class_name': _selectedClass,
      'title': _title,
      'fee_type': _feeType,
      'fee_plan': _feePlan,
      'academic_year': ref.read(studentFeeProvider).selectedAcademicYear,
      'amount': amt,
      'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk invoices queued and generated!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
