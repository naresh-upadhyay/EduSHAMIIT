import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/staff_salary_models.dart';
import '../../../providers/staff_salary_provider.dart';
import '../../../services/payment_management_api_service.dart';

class EditStaffSalaryStructureDialog extends ConsumerStatefulWidget {
  final String? staffId;
  final String? staffName;
  final StaffSalaryStructureItem? initialStructure;
  final double currentBasic;
  final double currentHra;
  final String? initialBankName;
  final String? initialAccountNumber;

  const EditStaffSalaryStructureDialog({
    super.key,
    this.staffId,
    this.staffName,
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

  final TextEditingController _staffSearchCtrl = TextEditingController();

  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  bool _submitting = false;
  bool _loadingUnconfigured = false;

  String? _selectedStaffId;
  String? _selectedStaffName;
  String? _selectedEmployeeId;
  String? _selectedDepartment;
  String? _selectedDesignation;

  List<Map<String, dynamic>> _unconfiguredStaffList = [];

  bool get _isEditMode => widget.initialStructure != null || widget.staffId != null;

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.staffId ?? widget.initialStructure?.staffId;
    _selectedStaffName = widget.staffName ?? widget.initialStructure?.staffName;
    _selectedEmployeeId = widget.initialStructure?.employeeId;
    _selectedDepartment = widget.initialStructure?.department;
    _selectedDesignation = widget.initialStructure?.designation;

    final s = widget.initialStructure;
    _basicController = TextEditingController(text: (s?.basicPay ?? widget.currentBasic).toInt().toString());
    _hraController = TextEditingController(text: (s?.hra ?? widget.currentHra).toInt().toString());
    _daController = TextEditingController(text: (s?.da ?? 5000.0).toInt().toString());
    _taController = TextEditingController(text: (s?.ta ?? 3000.0).toInt().toString());
    _specialController = TextEditingController(text: (s?.specialAllowance ?? 4000.0).toInt().toString());
    _medicalController = TextEditingController(text: (s?.medicalAllowance ?? 2000.0).toInt().toString());

    _pfController = TextEditingController(text: (s?.pfDeduction ?? 4200.0).toInt().toString());
    _tdsController = TextEditingController(text: (s?.tds ?? 2500.0).toInt().toString());
    _ptaxController = TextEditingController(text: (s?.professionalTax ?? 200.0).toInt().toString());
    _insuranceController = TextEditingController(text: (s?.insuranceDeduction ?? 1000.0).toInt().toString());

    _bankNameController = TextEditingController(text: s?.bankName ?? widget.initialBankName ?? 'HDFC Bank');
    _accountNumController = TextEditingController(text: s?.accountNumber ?? widget.initialAccountNumber ?? '');
    _ifscController = TextEditingController(text: s?.ifscCode ?? '');
    _panController = TextEditingController(text: s?.panNumber ?? '');
    _paymentMode = s?.paymentMode ?? 'Direct Bank Transfer (NEFT/RTGS)';

    if (!_isEditMode) {
      _loadUnconfiguredStaff();
    }
  }

  Future<void> _loadUnconfiguredStaff() async {
    setState(() => _loadingUnconfigured = true);
    final list = await PaymentManagementApiService.instance.getUnconfiguredStaffForSalary();
    if (mounted) {
      setState(() {
        _unconfiguredStaffList = list;
        _loadingUnconfigured = false;

        // Auto select first unconfigured staff member if none selected
        if (_selectedStaffId == null && list.isNotEmpty) {
          _onSelectStaff(list.first);
        }
      });
    }
  }



  void _onSelectStaff(Map<String, dynamic> staff) {
    setState(() {
      _selectedStaffId = staff['staff_id']?.toString();
      _selectedStaffName = staff['staff_name']?.toString();
      _selectedEmployeeId = staff['employee_id']?.toString();
      _selectedDepartment = staff['department']?.toString();
      _selectedDesignation = staff['designation']?.toString();

      // Auto-populate banking and tax credentials from user's canonical profile (SSOT)
      if ((staff['pan_number']?.toString().isNotEmpty ?? false) && _panController.text.isEmpty) {
        _panController.text = staff['pan_number'].toString();
      }
      if ((staff['bank_name']?.toString().isNotEmpty ?? false)) {
        _bankNameController.text = staff['bank_name'].toString();
      }
      if ((staff['account_number']?.toString().isNotEmpty ?? false)) {
        _accountNumController.text = staff['account_number'].toString();
      }
      if ((staff['ifsc_code']?.toString().isNotEmpty ?? false)) {
        _ifscController.text = staff['ifsc_code'].toString();
      }
    });
  }

  void _applyGradePreset(String grade) {
    setState(() {
      switch (grade) {
        case 'Senior Faculty / HOD':
          _basicController.text = '45000';
          _hraController.text = '18000';
          _daController.text = '8000';
          _taController.text = '4500';
          _specialController.text = '5000';
          _medicalController.text = '2500';
          _pfController.text = '5400';
          _tdsController.text = '3850';
          _ptaxController.text = '200';
          _insuranceController.text = '1000';
          break;
        case 'Faculty / Lecturer':
          _basicController.text = '35000';
          _hraController.text = '14000';
          _daController.text = '5000';
          _taController.text = '3000';
          _specialController.text = '4000';
          _medicalController.text = '2000';
          _pfController.text = '4200';
          _tdsController.text = '2500';
          _ptaxController.text = '200';
          _insuranceController.text = '1000';
          break;
        case 'Administrative Staff':
          _basicController.text = '26000';
          _hraController.text = '10400';
          _daController.text = '4000';
          _taController.text = '2500';
          _specialController.text = '3000';
          _medicalController.text = '1500';
          _pfController.text = '3120';
          _tdsController.text = '1200';
          _ptaxController.text = '200';
          _insuranceController.text = '500';
          break;
        case 'Support & Technical':
          _basicController.text = '18000';
          _hraController.text = '7200';
          _daController.text = '3000';
          _taController.text = '2000';
          _specialController.text = '2000';
          _medicalController.text = '1000';
          _pfController.text = '2160';
          _tdsController.text = '500';
          _ptaxController.text = '200';
          _insuranceController.text = '500';
          break;
      }
    });
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
    _staffSearchCtrl.dispose();
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
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar
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
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Edit Salary Compensation Structure' : 'Configure New Staff Salary Structure',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            _isEditMode
                                ? 'Update compensation tiers & statutory profile credentials'
                                : 'Select from staff members without configured compensation packages',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
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

              // 2. Staff Member Selection or Fixed Profile Card
              if (_isEditMode) ...[
                // Fixed SSOT Profile Card in Edit Mode
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        child: Text(
                          (_selectedStaffName?.isNotEmpty == true) ? _selectedStaffName![0].toUpperCase() : 'S',
                          style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStaffName ?? 'Staff Member',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (_selectedEmployeeId != null && _selectedEmployeeId!.isNotEmpty)
                                  _metaBadge(_selectedEmployeeId!, const Color(0xFF64748B), isDark),
                                if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty)
                                  _metaBadge(_selectedDepartment!, const Color(0xFF2563EB), isDark),
                                if (_selectedDesignation != null && _selectedDesignation!.isNotEmpty)
                                  _metaBadge(_selectedDesignation!, const Color(0xFF059669), isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CONFIGURED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                // Add Mode: Select from UNCONFIGURED staff members only
                Text(
                  'Select Unconfigured Staff Member',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Showing active staff who do not yet have a salary structure in the database',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),

                if (_loadingUnconfigured)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_unconfiguredStaffList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All active staff members currently have salary structures configured! Use the grid edit icon to update existing structures.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Search & Dropdown for unconfigured staff
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: _selectedStaffId,
                            isExpanded: true,
                            hint: const Text('Choose an unconfigured staff member...', style: TextStyle(fontSize: 13)),
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: _unconfiguredStaffList.map((s) {
                              final name = s['staff_name'] ?? 'Staff';
                              final empId = s['employee_id'] ?? '';
                              final dept = s['department'] ?? '';
                              final desig = s['designation'] ?? '';
                              return DropdownMenuItem<String>(
                                value: s['staff_id']?.toString(),
                                child: Text(
                                  '$name • $desig ($dept) | $empId',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final match = _unconfiguredStaffList.firstWhere(
                                  (e) => e['staff_id']?.toString() == val,
                                  orElse: () => _unconfiguredStaffList.first,
                                );
                                _onSelectStaff(match);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],

              // 3. Compensation Grade Presets (Enterprise HR Standard)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HR Compensation Presets',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  Text(
                    'Click to apply formula',
                    style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _presetChip('Senior Faculty / HOD', '₹ 82.5k', isDark),
                    const SizedBox(width: 6),
                    _presetChip('Faculty / Lecturer', '₹ 63k', isDark),
                    const SizedBox(width: 6),
                    _presetChip('Administrative Staff', '₹ 45.4k', isDark),
                    const SizedBox(width: 6),
                    _presetChip('Support & Technical', '₹ 31.2k', isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Live Net Salary Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Gross Earnings', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_gross.toInt())}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    Text('-', style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                    Column(
                      children: [
                        Text('Total Deductions', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_deductions.toInt())}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFDC2626))),
                      ],
                    ),
                    Text('=', style: TextStyle(fontSize: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                    Column(
                      children: [
                        Text('Net Take-Home', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text('₹ ${NumberFormat('#,##,###').format(_net.toInt())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Earnings Breakdown
              const Text(
                'EARNINGS & ALLOWANCES',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8B5CF6), letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Basic Pay', _basicController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('House Rent Allow. (HRA)', _hraController, isDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Dearness Allow. (DA)', _daController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Transport Allow. (TA)', _taController, isDark)),
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

              // 6. Statutory Deductions
              const Text(
                'STATUTORY DEDUCTIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626), letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('PF Deduction', _pfController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('TDS (Income Tax)', _tdsController, isDark)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field('Professional Tax (PT)', _ptaxController, isDark)),
                  const SizedBox(width: 10),
                  Expanded(child: _field('Insurance / ESI', _insuranceController, isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // 7. Banking & Statutory Tax Profile (SSOT)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BANKING & TAX PROFILE (PROFILE SSOT)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB), letterSpacing: 0.6),
                  ),
                  Text('Syncs to Employee Profile', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                ],
              ),
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
                  Expanded(child: _field('PAN Card Number', _panController, isDark, isNumber: false)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Disbursal Channel Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: _paymentMode,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'Direct Bank Transfer (NEFT/RTGS)', child: Text('Direct Bank Transfer (NEFT/RTGS)')),
                      DropdownMenuItem(value: 'UPI Direct', child: Text('UPI Direct')),
                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentMode = val);
                    },
                  ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEditMode ? 'Update Structure' : 'Save & Activate Structure', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(String label, String approxCtc, bool isDark) {
    return InkWell(
      onTap: () => _applyGradePreset(label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(approxCtc, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
          ],
        ),
      ),
    );
  }

  Widget _metaBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
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
    final targetStaffId = _selectedStaffId ?? widget.staffId;
    if (targetStaffId == null || targetStaffId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an unconfigured staff member'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await ref.read(staffSalaryProvider.notifier).saveSalaryStructure({
      'staff_id': targetStaffId,
      'basic_pay': double.tryParse(_basicController.text) ?? 35000.0,
      'hra': double.tryParse(_hraController.text) ?? 14000.0,
      'da': double.tryParse(_daController.text) ?? 5000.0,
      'ta': double.tryParse(_taController.text) ?? 3000.0,
      'special_allowance': double.tryParse(_specialController.text) ?? 4000.0,
      'medical_allowance': double.tryParse(_medicalController.text) ?? 2000.0,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Salary structure saved and profile synchronized successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }
}
