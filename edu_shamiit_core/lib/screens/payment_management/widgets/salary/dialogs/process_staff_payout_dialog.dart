import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/payment_lookup_helper.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/staff_salary_provider.dart';
import 'staff_payslip_dialog.dart';

class ProcessStaffPayoutDialog extends ConsumerStatefulWidget {
  final String? preselectedStaffId;
  const ProcessStaffPayoutDialog({super.key, this.preselectedStaffId});

  @override
  ConsumerState<ProcessStaffPayoutDialog> createState() => _ProcessStaffPayoutDialogState();
}

class _ProcessStaffPayoutDialogState extends ConsumerState<ProcessStaffPayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStaffId;
  late TextEditingController _basicPayController;
  late TextEditingController _hraController;
  late TextEditingController _daController;
  late TextEditingController _taController;
  late TextEditingController _allowanceController;
  late TextEditingController _bonusController;
  late TextEditingController _pfController;
  late TextEditingController _tdsController;
  late TextEditingController _ptaxController;
  late TextEditingController _advanceDeductionController;
  late TextEditingController _remarksController;

  // Real payment tender details
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _txnRefController;
  late TextEditingController _upiIdController;
  late TextEditingController _chequeNoController;
  late TextEditingController _cashierController;

  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  String _payoutStatus = 'Paid';
  bool _submitting = false;

  List<PaymentLookupItem> _paymentModes = [];

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.preselectedStaffId;
    _basicPayController = TextEditingController(text: '45000');
    _hraController = TextEditingController(text: '18000');
    _daController = TextEditingController(text: '7000');
    _taController = TextEditingController(text: '4000');
    _allowanceController = TextEditingController(text: '3000');
    _bonusController = TextEditingController(text: '0');
    _pfController = TextEditingController(text: '5400');
    _tdsController = TextEditingController(text: '3850');
    _ptaxController = TextEditingController(text: '200');
    _advanceDeductionController = TextEditingController(text: '0');
    _remarksController = TextEditingController(text: 'Monthly salary credit');

    _bankNameController = TextEditingController(text: 'HDFC Bank');
    _accountNumberController = TextEditingController(text: '501002340055');
    _ifscController = TextEditingController(text: 'HDFC0001824');
    _txnRefController = TextEditingController(text: 'UTR-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    _upiIdController = TextEditingController(text: 'faculty@okaxis');
    _chequeNoController = TextEditingController(text: 'CHQ-892104');
    _cashierController = TextEditingController(text: 'Chief Cashier / Accounts');

    _loadLookups();
  }

  void _populateStaffDetails(String staffId) {
    final staff = ref.read(staffSalaryProvider).staffRoster.where((s) => s.staffId == staffId).firstOrNull;
    if (staff != null) {
      _basicPayController.text = staff.basicPay.toInt().toString();
      _hraController.text = staff.hra.toInt().toString();
      if (staff.bankName != null && staff.bankName!.isNotEmpty) {
        _bankNameController.text = staff.bankName!;
      }
      if (staff.accountNumber != null && staff.accountNumber!.isNotEmpty) {
        _accountNumberController.text = staff.accountNumber!;
      }
      if (staff.activeAdvanceDeduction > 0) {
        _advanceDeductionController.text = staff.activeAdvanceDeduction.toInt().toString();
      } else {
        _advanceDeductionController.text = '0';
      }
      _paymentMode = staff.paymentMode;
    }
  }

  Future<void> _loadLookups() async {
    final modes = await PaymentLookupHelper.instance.getActiveLookup('STAFF_SALARY_PAYMENT_MODE');
    if (mounted) {
      setState(() {
        _paymentModes = modes;
        if (modes.isNotEmpty) _paymentMode = modes.first.label;
      });
      if (_selectedStaffId != null) {
        _populateStaffDetails(_selectedStaffId!);
      }
    }
  }

  @override
  void dispose() {
    _basicPayController.dispose();
    _hraController.dispose();
    _daController.dispose();
    _taController.dispose();
    _allowanceController.dispose();
    _bonusController.dispose();
    _pfController.dispose();
    _tdsController.dispose();
    _ptaxController.dispose();
    _advanceDeductionController.dispose();
    _remarksController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _txnRefController.dispose();
    _upiIdController.dispose();
    _chequeNoController.dispose();
    _cashierController.dispose();
    super.dispose();
  }

  double get _gross =>
      (double.tryParse(_basicPayController.text) ?? 0) +
      (double.tryParse(_hraController.text) ?? 0) +
      (double.tryParse(_daController.text) ?? 0) +
      (double.tryParse(_taController.text) ?? 0) +
      (double.tryParse(_allowanceController.text) ?? 0) +
      (double.tryParse(_bonusController.text) ?? 0);

  double get _deductions =>
      (double.tryParse(_pfController.text) ?? 0) +
      (double.tryParse(_tdsController.text) ?? 0) +
      (double.tryParse(_ptaxController.text) ?? 0) +
      (double.tryParse(_advanceDeductionController.text) ?? 0);

  double get _net => _gross - _deductions;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffSalaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedStaffId == null && state.staffRoster.isNotEmpty) {
      _selectedStaffId = state.staffRoster.first.staffId;
      _populateStaffDetails(_selectedStaffId!);
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Process Salary Disbursal',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Real-time payment authorization & ledger credit',
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
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

                  // Staff Selector
                  Text('Select Staff Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                        final Map<String, String> staffMap = {};
                        for (final s in state.staffRoster) {
                          if (s.staffId.isNotEmpty) {
                            staffMap[s.staffId] = '${s.staffName} (${s.designation} - ${s.department})';
                          }
                        }
                        if (_selectedStaffId != null && _selectedStaffId!.isNotEmpty && !staffMap.containsKey(_selectedStaffId)) {
                          staffMap[_selectedStaffId!] = 'Staff Member';
                        }
                        final effectiveStaffId = staffMap.containsKey(_selectedStaffId)
                            ? _selectedStaffId
                            : (staffMap.isNotEmpty ? staffMap.keys.first : null);

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: ValueKey('process_staff_${effectiveStaffId ?? "none"}'),
                            value: effectiveStaffId,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: staffMap.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStaffId = val;
                                  _populateStaffDetails(val);
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Base Pay & Allowances Fields
                  const Text('Base Pay & Allowances (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildNumberInput('Basic Pay', _basicPayController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('HRA', _hraController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('DA', _daController, isDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildNumberInput('TA', _taController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('Special Allowance', _allowanceController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('Bonus', _bonusController, isDark)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Deductions Fields
                  const Text('Deductions (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildNumberInput('PF Deduction', _pfController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('TDS / Tax', _tdsController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('Prof. Tax', _ptaxController, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildNumberInput('Advance EMI', _advanceDeductionController, isDark)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Calculation Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gross: ₹ ${NumberFormat('#,##,###').format(_gross.toInt())}', style: const TextStyle(fontSize: 11)),
                            Text('Deductions: - ₹ ${NumberFormat('#,##,###').format(_deductions.toInt())}', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Take-Home Net Salary', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            Text(
                              '₹ ${NumberFormat('#,##,###').format(_net.toInt())}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Channel
                  Text('Payment Channel Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
                        final Map<String, String> modeMap = {};
                        if (_paymentModes.isNotEmpty) {
                          for (final m in _paymentModes) {
                            if (m.label.isNotEmpty) {
                              modeMap[m.label] = m.label;
                            }
                          }
                        }
                        final defaultModes = <String, String>{
                          'UPI': 'UPI / Corporate IMPS',
                          'Direct Bank Transfer (NEFT/RTGS)': 'Direct Bank Transfer (NEFT/RTGS)',
                          'UPI / Corporate IMPS': 'UPI / Corporate IMPS',
                          'Corporate Cheque': 'Corporate Cheque',
                          'Cash Voucher': 'Cash Voucher',
                          'Cash': 'Cash Voucher',
                          'Bank Transfer': 'Direct Bank Transfer (NEFT/RTGS)',
                        };

                        if (modeMap.isEmpty) {
                          modeMap['Direct Bank Transfer (NEFT/RTGS)'] = 'Direct Bank Transfer (NEFT/RTGS)';
                          modeMap['UPI / Corporate IMPS'] = 'UPI / Corporate IMPS';
                          modeMap['Corporate Cheque'] = 'Corporate Cheque';
                          modeMap['Cash Voucher'] = 'Cash Voucher';
                        }

                        String effectiveMode = _paymentMode;
                        if (!modeMap.containsKey(effectiveMode)) {
                          final matchedKey = modeMap.keys.firstWhere(
                            (k) => k.toLowerCase() == effectiveMode.toLowerCase() ||
                                   k.toLowerCase().contains(effectiveMode.toLowerCase()) ||
                                   effectiveMode.toLowerCase().contains(k.toLowerCase()),
                            orElse: () => '',
                          );
                          if (matchedKey.isNotEmpty) {
                            effectiveMode = matchedKey;
                          } else {
                            final label = defaultModes[effectiveMode] ?? effectiveMode;
                            modeMap[effectiveMode] = label;
                          }
                        }

                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: ValueKey('process_pay_mode_$effectiveMode'),
                            value: effectiveMode,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: modeMap.entries.map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMode = val);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Context Tender Fields based on payment mode
                  if (_paymentMode.contains('Bank') || _paymentMode.contains('NEFT')) ...[
                    Row(
                      children: [
                        Expanded(child: _buildTextInput('Bank Name', _bankNameController, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextInput('Account Number', _accountNumberController, isDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildTextInput('IFSC Code', _ifscController, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextInput('UTR / Txn Ref', _txnRefController, isDark)),
                      ],
                    ),
                  ] else if (_paymentMode.contains('UPI')) ...[
                    Row(
                      children: [
                        Expanded(child: _buildTextInput('Recipient UPI ID / VPA', _upiIdController, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextInput('UPI Ref / RR No.', _txnRefController, isDark)),
                      ],
                    ),
                  ] else if (_paymentMode.contains('Cheque')) ...[
                    Row(
                      children: [
                        Expanded(child: _buildTextInput('Cheque Number', _chequeNoController, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTextInput('Issuing Bank Name', _bankNameController, isDark)),
                      ],
                    ),
                  ] else ...[
                    _buildTextInput('Authorized Cashier / Counter', _cashierController, isDark),
                  ],

                  const SizedBox(height: 12),
                  _buildTextInput('Remarks / Audit Notes', _remarksController, isDark),
                  const SizedBox(height: 16),

                  // Initial Payout Status Selection
                  Text('Disbursal Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Paid', 'Pending', 'On Hold'].map((st) {
                      final isSel = _payoutStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          onSelected: (_) => setState(() => _payoutStatus = st),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _payoutStatus == 'Paid' ? 'Disburse & Authorize' : 'Save as $_payoutStatus',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _submitting ? null : _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedStaffId == null) return;
    final bpay = double.tryParse(_basicPayController.text.trim()) ?? 0.0;
    if (bpay <= 0) return;

    setState(() => _submitting = true);
    final monthStr = ref.read(staffSalaryProvider).selectedMonthStr;
    final parts = monthStr.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 10;

    final staffMatch = ref.read(staffSalaryProvider).staffRoster.firstWhere((e) => e.staffId == _selectedStaffId);

    final payload = {
      'staff_id': _selectedStaffId,
      'month': month,
      'year': year,
      'month_str': monthStr,
      'basic_pay': bpay,
      'hra': double.tryParse(_hraController.text) ?? 0,
      'da': double.tryParse(_daController.text) ?? 0,
      'ta': double.tryParse(_taController.text) ?? 0,
      'special_allowance': double.tryParse(_allowanceController.text) ?? 0,
      'bonus': double.tryParse(_bonusController.text) ?? 0,
      'pf_deduction': double.tryParse(_pfController.text) ?? 0,
      'tds': double.tryParse(_tdsController.text) ?? 0,
      'professional_tax': double.tryParse(_ptaxController.text) ?? 0,
      'advance_deduction': double.tryParse(_advanceDeductionController.text) ?? 0,
      'payment_status': _payoutStatus,
      'payment_mode': _paymentMode,
      'transaction_reference': _txnRefController.text.trim(),
      'remarks': _remarksController.text.trim(),
    };

    final ok = await PaymentManagementApiService.instance.processStaffPayout(payload);

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Salary of ₹ ${NumberFormat('#,##,###').format(_net.toInt())} for ${staffMatch.staffName} disbursed successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );

        // Open Payslip Preview immediately for Print / Download
        showDialog(
          context: context,
          builder: (ctx) => StaffPayslipDialog(
            payslip: {
              'staff_name': staffMatch.staffName,
              'employee_id': staffMatch.employeeId,
              'designation': staffMatch.designation,
              'department': staffMatch.department,
              'payslip_number': 'PS-$monthStr-${staffMatch.employeeId}',
              'month_str': monthStr,
              'basic_pay': bpay,
              'hra': double.tryParse(_hraController.text) ?? 0,
              'da': double.tryParse(_daController.text) ?? 0,
              'ta': double.tryParse(_taController.text) ?? 0,
              'special_allowance': double.tryParse(_allowanceController.text) ?? 0,
              'bonus': double.tryParse(_bonusController.text) ?? 0,
              'pf_deduction': double.tryParse(_pfController.text) ?? 0,
              'tds': double.tryParse(_tdsController.text) ?? 0,
              'professional_tax': double.tryParse(_ptaxController.text) ?? 200,
              'advance_deduction': double.tryParse(_advanceDeductionController.text) ?? 0,
              'net_pay': _net,
              'payment_mode': _paymentMode,
              'transaction_reference': _txnRefController.text.trim(),
              'bank_name': _bankNameController.text.trim(),
              'account_number': _accountNumberController.text.trim(),
            },
          ),
        );
      }
    }
  }
}
