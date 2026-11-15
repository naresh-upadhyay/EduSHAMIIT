import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/staff_salary_models.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/staff_salary_provider.dart';

class EditStaffSalaryStructureDialog extends ConsumerStatefulWidget {
  final String staffId;
  final String staffName;
  final StaffSalaryStructureItem? initialStructure;
  final double currentBasic;
  final double currentHra;
  final String? initialBankName;
  final String? initialAccountNumber;

  const EditStaffSalaryStructureDialog({
    super.key,
    required this.staffId,
    required this.staffName,
    this.initialStructure,
    this.currentBasic = 35000.0,
    this.currentHra = 14000.0,
    this.initialBankName,
    this.initialAccountNumber,
  });

  @override
  ConsumerState<EditStaffSalaryStructureDialog> createState() => _EditStaffSalaryStructureDialogState();
}

class _EditStaffSalaryStructureDialogState extends ConsumerState<EditStaffSalaryStructureDialog> {
  late TextEditingController _basicController;
  late TextEditingController _hraController;
  late TextEditingController _daController;
  late TextEditingController _taController;
  late TextEditingController _specialController;
  late TextEditingController _medicalController;
  late TextEditingController _pfController;
  late TextEditingController _tdsController;
  late TextEditingController _ptaxController;
  late TextEditingController _insuranceController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumController;
  late TextEditingController _ifscController;
  late TextEditingController _panController;

  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStructure;
    _basicController = TextEditingController(text: (s?.basicPay ?? widget.currentBasic).toInt().toString());
    _hraController = TextEditingController(text: (s?.hra ?? widget.currentHra).toInt().toString());
    _daController = TextEditingController(text: (s?.da ?? 6000.0).toInt().toString());
    _taController = TextEditingController(text: (s?.ta ?? 3500.0).toInt().toString());
    _specialController = TextEditingController(text: (s?.specialAllowance ?? 3000.0).toInt().toString());
    _medicalController = TextEditingController(text: (s?.medicalAllowance ?? 1500.0).toInt().toString());

    _pfController = TextEditingController(text: (s?.pfDeduction ?? 4200.0).toInt().toString());
    _tdsController = TextEditingController(text: (s?.tds ?? 2500.0).toInt().toString());
    _ptaxController = TextEditingController(text: (s?.professionalTax ?? 200.0).toInt().toString());
    _insuranceController = TextEditingController(text: (s?.insuranceDeduction ?? 1000.0).toInt().toString());

    _bankNameController = TextEditingController(text: s?.bankName ?? widget.initialBankName ?? 'HDFC Bank');
    _accountNumController = TextEditingController(text: s?.accountNumber ?? widget.initialAccountNumber ?? '');
    _ifscController = TextEditingController(text: s?.ifscCode ?? '');
    _panController = TextEditingController(text: s?.panNumber ?? '');
    _paymentMode = s?.paymentMode ?? 'Direct Bank Transfer (NEFT/RTGS)';
  }

  @override
  void dispose() {
    _basicController.dispose();
    _hraController.dispose();
    _daController.dispose();
    _taController.dispose();
    _specialController.dispose();
    _medicalController.dispose();
    _pfController.dispose();
    _tdsController.dispose();
    _ptaxController.dispose();
    _insuranceController.dispose();
    _bankNameController.dispose();
    _accountNumController.dispose();
    _ifscController.dispose();
    _panController.dispose();
    super.dispose();
  }

  double get _gross =>
      (double.tryParse(_basicController.text) ?? 0) +
      (double.tryParse(_hraController.text) ?? 0) +
      (double.tryParse(_daController.text) ?? 0) +
      (double.tryParse(_taController.text) ?? 0) +
      (double.tryParse(_specialController.text) ?? 0) +
      (double.tryParse(_medicalController.text) ?? 0);

  double get _deductions =>
      (double.tryParse(_pfController.text) ?? 0) +
      (double.tryParse(_tdsController.text) ?? 0) +
      (double.tryParse(_ptaxController.text) ?? 0) +
      (double.tryParse(_insuranceController.text) ?? 0);

  double get _net => _gross - _deductions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                        child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Salary Structure & Bank Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text(widget.staffName, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              // Live Summary Preview Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Gross Earnings', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_gross.toInt())}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF16A34A))),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Total Deductions', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_deductions.toInt())}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626))),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Net Take-Home', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_net.toInt())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('EARNINGS BREAKDOWN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Basic Pay', _basicController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('HRA', _hraController, isDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('DA', _daController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('TA', _taController, isDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Special Allowance', _specialController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Medical Allowance', _medicalController, isDark)),
                ],
              ),
              const SizedBox(height: 16),

              const Text('STATUTORY DEDUCTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Provident Fund (PF)', _pfController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('TDS (Income Tax)', _tdsController, isDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Professional Tax', _ptaxController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Insurance Deduction', _insuranceController, isDark)),
                ],
              ),
              const SizedBox(height: 16),

              const Text('BANKING & DISBURSAL CREDENTIALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Bank Name', _bankNameController, isDark, isNumber: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Account Number', _accountNumController, isDark, isNumber: false)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('IFSC Code', _ifscController, isDark, isNumber: false)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('PAN Number', _panController, isDark, isNumber: false)),
                ],
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
                        : const Text('Save Structure', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, bool isDark, {bool isNumber = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixText: isNumber ? '₹ ' : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final ok = await PaymentManagementApiService.instance.updateStaffSalaryStructure(widget.staffId, {
      'staff_id': widget.staffId,
      'basic_pay': double.tryParse(_basicController.text) ?? 35000.0,
      'hra': double.tryParse(_hraController.text) ?? 14000.0,
      'da': double.tryParse(_daController.text) ?? 6000.0,
      'ta': double.tryParse(_taController.text) ?? 3500.0,
      'special_allowance': double.tryParse(_specialController.text) ?? 3000.0,
      'medical_allowance': double.tryParse(_medicalController.text) ?? 1500.0,
      'pf_deduction': double.tryParse(_pfController.text) ?? 4200.0,
      'tds': double.tryParse(_tdsController.text) ?? 2500.0,
      'professional_tax': double.tryParse(_ptaxController.text) ?? 200.0,
      'insurance_deduction': double.tryParse(_insuranceController.text) ?? 1000.0,
      'payment_mode': _paymentMode,
      'bank_name': _bankNameController.text.trim(),
      'account_number': _accountNumController.text.trim(),
      'ifsc_code': _ifscController.text.trim(),
      'pan_number': _panController.text.trim(),
    });

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary structure updated successfully!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    }
  }
}
