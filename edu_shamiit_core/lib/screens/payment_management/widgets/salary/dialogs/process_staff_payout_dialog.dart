import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
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

  // Selected Month & Period
  late String _selectedMonthStr;
  final List<String> _availableMonths = [
    '2026-10',
    '2026-11',
    '2026-12',
    '2027-01',
    '2027-02',
    '2027-03',
    '2026-09',
    '2026-08',
    '2026-07',
    '2026-06',
    '2026-05',
    '2026-04',
  ];

  // Global Staff Search & Selection State
  String? _selectedStaffId;
  Map<String, dynamic>? _selectedStaffRecord;
  List<Map<String, dynamic>> _globalStaffList = [];
  bool _searchingStaff = false;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Earnings Form Controllers
  late TextEditingController _basicPayController;
  late TextEditingController _hraController;
  late TextEditingController _daController;
  late TextEditingController _taController;
  late TextEditingController _allowanceController;
  late TextEditingController _medicalController;
  late TextEditingController _bonusController;

  // Variable Bonus Classification & Remarks
  String _bonusType = 'NONE';
  late TextEditingController _bonusRemarksController;
  final List<Map<String, String>> _bonusTypeOptions = [
    {'value': 'NONE', 'label': 'No Bonus / Standard Cycle'},
    {'value': 'MONTHLY_INCENTIVE', 'label': 'Monthly Performance Incentive'},
    {'value': 'QUARTERLY_KPI_Q1', 'label': 'Quarterly KPI Bonus (Q1 Apr-Jun)'},
    {'value': 'QUARTERLY_KPI_Q2', 'label': 'Quarterly KPI Bonus (Q2 Jul-Sep)'},
    {'value': 'QUARTERLY_KPI_Q3', 'label': 'Quarterly KPI Bonus (Q3 Oct-Dec)'},
    {'value': 'QUARTERLY_KPI_Q4', 'label': 'Quarterly KPI Bonus (Q4 Jan-Mar)'},
    {'value': 'HALF_YEARLY_H1', 'label': 'Half-Yearly Appraisal (H1)'},
    {'value': 'HALF_YEARLY_H2', 'label': 'Half-Yearly Appraisal (H2)'},
    {'value': 'ANNUAL_MERIT', 'label': 'Annual Merit / Appraisal Bonus'},
    {'value': 'FESTIVAL', 'label': 'Festival / Diwali Ex-Gratia Bonus'},
    {'value': 'ARREARS', 'label': 'Salary Arrears / Special Adjustment'},
  ];

  // Deductions Form Controllers
  late TextEditingController _pfController;
  late TextEditingController _tdsController;
  late TextEditingController _ptaxController;
  late TextEditingController _insuranceController;
  late TextEditingController _advanceDeductionController;
  late TextEditingController _otherDeductionsController;
  late TextEditingController _otherDeductionsRemarksController;

  // Contract Structure Update Toggle
  bool _updatePermanentStructure = false;

  // Tender & Banking Controllers
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _panNumberController;
  late TextEditingController _txnRefController;
  late TextEditingController _upiIdController;
  late TextEditingController _chequeNoController;
  late TextEditingController _cashierController;
  late TextEditingController _remarksController;

  String _paymentMode = 'Direct Bank Transfer (NEFT/RTGS)';
  String _payoutStatus = 'Paid';
  bool _submitting = false;
  bool _loadingStaffDetail = false;
  String? _errorMessage;

  // Active Loan Details
  bool _hasActiveLoans = false;
  bool _recoverLoanEmi = true;
  double _totalOutstandingLoans = 0.0;
  double _standardMonthlyLoanEmi = 0.0;
  int _activeLoanCount = 0;
  List<Map<String, dynamic>> _activeLoans = [];

  List<PaymentLookupItem> _paymentModes = [];

  @override
  void initState() {
    super.initState();
    _selectedStaffId = widget.preselectedStaffId;

    final initialMonth = ref.read(staffSalaryProvider).selectedMonthStr;
    _selectedMonthStr = _availableMonths.contains(initialMonth) ? initialMonth : '2026-10';

    _basicPayController = TextEditingController(text: '35000');
    _hraController = TextEditingController(text: '14000');
    _daController = TextEditingController(text: '5000');
    _taController = TextEditingController(text: '2500');
    _allowanceController = TextEditingController(text: '3000');
    _medicalController = TextEditingController(text: '1500');
    _bonusController = TextEditingController(text: '0');
    _bonusRemarksController = TextEditingController();

    _pfController = TextEditingController(text: '4200');
    _tdsController = TextEditingController(text: '2500');
    _ptaxController = TextEditingController(text: '200');
    _insuranceController = TextEditingController(text: '1000');
    _advanceDeductionController = TextEditingController(text: '0');
    _otherDeductionsController = TextEditingController(text: '0');
    _otherDeductionsRemarksController = TextEditingController();

    _bankNameController = TextEditingController(text: 'State Bank of India');
    _accountNumberController = TextEditingController(text: '');
    _ifscController = TextEditingController(text: '');
    _panNumberController = TextEditingController(text: '');
    _txnRefController = TextEditingController(
      text: 'UTR-${DateFormat('yyyyMMdd').format(DateTime.now())}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _upiIdController = TextEditingController(text: '');
    _chequeNoController = TextEditingController(text: 'CHQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    _cashierController = TextEditingController(text: 'Chief Cashier / Accounts Desk');
    _remarksController = TextEditingController(text: 'Monthly salary disbursal for $_selectedMonthStr');

    _initData();
  }

  Future<void> _initData() async {
    await _loadLookups();
    await _fetchGlobalStaffList(query: '');
  }

  Future<void> _loadLookups() async {
    final modes = await PaymentLookupHelper.instance.getActiveLookup('STAFF_SALARY_PAYMENT_MODE');
    if (mounted) {
      setState(() {
        _paymentModes = modes;
        if (modes.isNotEmpty && _paymentMode.isEmpty) {
          _paymentMode = modes.first.label;
        }
      });
    }
  }

  Future<void> _fetchGlobalStaffList({String query = ''}) async {
    if (!mounted) return;
    setState(() => _searchingStaff = true);

    final results = await PaymentManagementApiService.instance.searchAllStaffForPayroll(
      search: query,
      monthStr: _selectedMonthStr,
    );

    if (mounted) {
      setState(() {
        _globalStaffList = results;
        _searchingStaff = false;

        // If preselected or selected staff ID exists, link the record
        if (_selectedStaffId != null) {
          final match = _globalStaffList.where((s) => s['staff_id'] == _selectedStaffId).firstOrNull;
          if (match != null) {
            _selectStaffRecord(match);
          } else if (_selectedStaffRecord == null && _globalStaffList.isNotEmpty) {
            _selectStaffRecord(_globalStaffList.first);
          }
        } else if (_globalStaffList.isNotEmpty) {
          _selectStaffRecord(_globalStaffList.first);
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchGlobalStaffList(query: query);
    });
  }

  void _onMonthChanged(String newMonth) {
    setState(() {
      _selectedMonthStr = newMonth;
      _remarksController.text = 'Monthly salary disbursal for $_selectedMonthStr';
    });
    _fetchGlobalStaffList(query: _searchController.text.trim());
  }

  void _selectStaffRecord(Map<String, dynamic> staff) {
    setState(() {
      _selectedStaffId = staff['staff_id']?.toString();
      _selectedStaffRecord = staff;

      // Base Structure Allowances
      _basicPayController.text = ((staff['basic_pay'] as num?)?.toDouble() ?? 35000.0).toInt().toString();
      _hraController.text = ((staff['hra'] as num?)?.toDouble() ?? 14000.0).toInt().toString();
      _daController.text = ((staff['da'] as num?)?.toDouble() ?? 5000.0).toInt().toString();
      _taController.text = ((staff['ta'] as num?)?.toDouble() ?? 2500.0).toInt().toString();
      _allowanceController.text = ((staff['special_allowance'] as num?)?.toDouble() ?? 3000.0).toInt().toString();
      _medicalController.text = ((staff['medical_allowance'] as num?)?.toDouble() ?? 1500.0).toInt().toString();

      // Statutory Deductions
      _pfController.text = ((staff['pf_deduction'] as num?)?.toDouble() ?? 4200.0).toInt().toString();
      _tdsController.text = ((staff['tds'] as num?)?.toDouble() ?? 2500.0).toInt().toString();
      _ptaxController.text = ((staff['professional_tax'] as num?)?.toDouble() ?? 200.0).toInt().toString();
      _insuranceController.text = ((staff['insurance_deduction'] as num?)?.toDouble() ?? 1000.0).toInt().toString();

      // Tender & Banking
      final bName = staff['bank_name']?.toString() ?? '';
      if (bName.isNotEmpty) _bankNameController.text = bName;
      final accNo = staff['account_number']?.toString() ?? '';
      if (accNo.isNotEmpty) _accountNumberController.text = accNo;
      final ifsc = staff['ifsc_code']?.toString() ?? '';
      if (ifsc.isNotEmpty) _ifscController.text = ifsc;
      final pan = staff['pan_number']?.toString() ?? '';
      if (pan.isNotEmpty) _panNumberController.text = pan;

      final pMode = staff['payment_mode']?.toString() ?? '';
      if (pMode.isNotEmpty) _paymentMode = pMode;

      // Active Loans
      final advBal = (staff['active_advance_balance'] as num?)?.toDouble() ?? 0.0;
      final advEmi = (staff['advance_monthly_emi'] as num?)?.toDouble() ?? 0.0;
      if (advBal > 0) {
        _hasActiveLoans = true;
        _totalOutstandingLoans = advBal;
        _standardMonthlyLoanEmi = advEmi > 0 ? advEmi : (advBal / 3);
        _advanceDeductionController.text = _standardMonthlyLoanEmi.toInt().toString();
      } else {
        _hasActiveLoans = false;
        _totalOutstandingLoans = 0.0;
        _standardMonthlyLoanEmi = 0.0;
        _advanceDeductionController.text = '0';
      }

      // Check payout status for this specific month
      final pStatus = staff['payout_status']?.toString() ?? 'Pending';
      if (pStatus == 'Paid') {
        _payoutStatus = 'Paid';
        if (staff['payout_txn_ref'] != null) {
          _txnRefController.text = staff['payout_txn_ref'].toString();
        }
        _bonusController.text = ((staff['payout_bonus'] as num?)?.toDouble() ?? 0.0).toInt().toString();
        _bonusType = staff['payout_bonus_type']?.toString() ?? 'NONE';
        _bonusRemarksController.text = staff['payout_bonus_remarks']?.toString() ?? '';
        _otherDeductionsController.text = ((staff['payout_other_deductions'] as num?)?.toDouble() ?? 0.0).toInt().toString();
        _otherDeductionsRemarksController.text = staff['payout_other_deductions_remarks']?.toString() ?? '';
      } else if (pStatus == 'On Hold' || pStatus == 'On-Hold') {
        _payoutStatus = 'On Hold';
        _bonusController.text = ((staff['payout_bonus'] as num?)?.toDouble() ?? 0.0).toInt().toString();
        _bonusType = staff['payout_bonus_type']?.toString() ?? 'NONE';
        _bonusRemarksController.text = staff['payout_bonus_remarks']?.toString() ?? '';
        _otherDeductionsController.text = ((staff['payout_other_deductions'] as num?)?.toDouble() ?? 0.0).toInt().toString();
        _otherDeductionsRemarksController.text = staff['payout_other_deductions_remarks']?.toString() ?? '';
        _txnRefController.text = staff['payout_txn_ref']?.toString() ?? 'UTR-${DateFormat('yyyyMMdd').format(DateTime.now())}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      } else {
        _payoutStatus = 'Pending';
        _bonusController.text = '0';
        _bonusType = 'NONE';
        _bonusRemarksController.clear();
        _otherDeductionsController.text = '0';
        _otherDeductionsRemarksController.clear();
        _txnRefController.text = 'UTR-${DateFormat('yyyyMMdd').format(DateTime.now())}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }

      final sName = staff['full_name']?.toString() ?? 'Employee';
      _remarksController.text = 'Monthly salary credit for $sName ($_selectedMonthStr)';
    });

    if (_selectedStaffId != null) {
      _fetchFullStaffDetail(_selectedStaffId!);
    }
  }

  Future<void> _fetchFullStaffDetail(String staffId) async {
    if (!mounted) return;
    setState(() => _loadingStaffDetail = true);

    try {
      final detail = await PaymentManagementApiService.instance.getStaffSalaryDetail(staffId);
      if (detail != null && mounted) {
        final advancesRaw = detail['advances'] as List?;
        if (advancesRaw != null && advancesRaw.isNotEmpty) {
          final List<Map<String, dynamic>> activeList = [];
          double totalBalance = 0.0;
          double totalEmi = 0.0;

          for (final adv in advancesRaw) {
            if (adv is Map) {
              final status = adv['status']?.toString() ?? '';
              final amt = (adv['amount'] as num?)?.toDouble() ?? 0.0;
              final repaid = (adv['amount_repaid'] as num?)?.toDouble() ?? 0.0;
              final emi = (adv['monthly_deduction'] as num?)?.toDouble() ?? (amt / 3);
              final balance = amt - repaid;

              if (status.toLowerCase() == 'approved' && balance > 0) {
                activeList.add(Map<String, dynamic>.from(adv));
                totalBalance += balance;
                totalEmi += emi;
              }
            }
          }

          if (activeList.isNotEmpty) {
            setState(() {
              _hasActiveLoans = true;
              _activeLoans = activeList;
              _activeLoanCount = activeList.length;
              _totalOutstandingLoans = totalBalance;
              _standardMonthlyLoanEmi = totalEmi;

              final recommendedDeduction = totalEmi > totalBalance ? totalBalance : totalEmi;
              _advanceDeductionController.text = recommendedDeduction.toInt().toString();
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingStaffDetail = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _basicPayController.dispose();
    _hraController.dispose();
    _daController.dispose();
    _taController.dispose();
    _allowanceController.dispose();
    _medicalController.dispose();
    _bonusController.dispose();
    _bonusRemarksController.dispose();

    _pfController.dispose();
    _tdsController.dispose();
    _ptaxController.dispose();
    _insuranceController.dispose();
    _advanceDeductionController.dispose();
    _otherDeductionsController.dispose();
    _otherDeductionsRemarksController.dispose();

    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _panNumberController.dispose();
    _txnRefController.dispose();
    _upiIdController.dispose();
    _chequeNoController.dispose();
    _cashierController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _gross =>
      (double.tryParse(_basicPayController.text) ?? 0) +
      (double.tryParse(_hraController.text) ?? 0) +
      (double.tryParse(_daController.text) ?? 0) +
      (double.tryParse(_taController.text) ?? 0) +
      (double.tryParse(_allowanceController.text) ?? 0) +
      (double.tryParse(_medicalController.text) ?? 0) +
      (double.tryParse(_bonusController.text) ?? 0);

  double get _deductions =>
      (double.tryParse(_pfController.text) ?? 0) +
      (double.tryParse(_tdsController.text) ?? 0) +
      (double.tryParse(_ptaxController.text) ?? 0) +
      (double.tryParse(_insuranceController.text) ?? 0) +
      (double.tryParse(_advanceDeductionController.text) ?? 0) +
      (double.tryParse(_otherDeductionsController.text) ?? 0);

  double get _net => (_gross - _deductions) > 0 ? (_gross - _deductions) : 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Executive Header with Pay Period Selector
              _buildHeader(isDark),

              // 2. Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error Banner
                      if (_errorMessage != null) _buildErrorBanner(),

                      // Global Staff Search & Selector Bar
                      _buildGlobalStaffSearchSection(isDark),
                      const SizedBox(height: 14),

                      // Selected Staff Detail Card with Status Callout
                      _buildSelectedStaffSummaryCard(isDark),
                      const SizedBox(height: 16),

                      // Active Loans / Advances Recovery Card
                      if (_hasActiveLoans || _loadingStaffDetail)
                        _buildActiveLoansCard(isDark)
                      else
                        _buildNoLoansCard(isDark),
                      const SizedBox(height: 16),

                      // Two-Column Financial Computation Grid
                      _buildFinancialGrid(isDark),
                      const SizedBox(height: 16),

                      // Permanent Salary Contract Revision Checkbox
                      _buildPermanentStructureUpdateCard(isDark),
                      const SizedBox(height: 16),

                      // Executive Net Pay Callout Banner
                      _buildNetPayBanner(isDark),
                      const SizedBox(height: 18),

                      // Payment Routing & Banking Tender
                      _buildPaymentRoutingCard(isDark),
                      const SizedBox(height: 16),

                      // Authorization & Disbursal Status
                      _buildAuthorizationSection(isDark),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Action Buttons
              _buildBottomActionButtons(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // Header Bar with Pay Period Selector
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive Payroll Disbursal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Global Database Search, Variable Bonus Engine & Audit Trail',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Pay Period Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedMonthStr,
                        isDense: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: _availableMonths.map((m) {
                          return DropdownMenuItem<String>(
                            value: m,
                            child: Text(
                              'Cycle: $m',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedMonthStr) {
                            _onMonthChanged(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Error Banner
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
            onPressed: () => setState(() => _errorMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // Global Staff Search & Selector Bar
  Widget _buildGlobalStaffSearchSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT EMPLOYEE ACROSS INSTITUTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            if (_searchingStaff)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)),
              )
            else
              Text(
                '${_globalStaffList.length} staff members loaded',
                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Search Input Field
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search staff by name, employee ID, department, or designation...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              _fetchGlobalStaffList(query: '');
                            },
                          )
                        : null,
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Staff Dropdown Selector
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: _selectedStaffId,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    hint: const Text('Select Employee', style: TextStyle(fontSize: 12)),
                    items: _globalStaffList.map((s) {
                      final sid = s['staff_id']?.toString() ?? '';
                      final sName = s['full_name']?.toString() ?? 'Staff';
                      final empId = s['employee_id']?.toString() ?? '';
                      final status = s['payout_status']?.toString() ?? 'Pending';
                      final isPaid = status == 'Paid';

                      return DropdownMenuItem<String>(
                        value: sid,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$sName ($empId)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Builder(
                              builder: (ctx) {
                                final isOnHold = status == 'On Hold' || status == 'On-Hold';
                                final bColor = isPaid
                                    ? const Color(0xFF16A34A)
                                    : isOnHold
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFF59E0B);
                                final bText = isPaid
                                    ? '✓ Paid'
                                    : isOnHold
                                        ? '⏸ On Hold'
                                        : '⏳ Pending';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: bColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: bColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = _globalStaffList.where((s) => s['staff_id'] == val).firstOrNull;
                        if (found != null) {
                          _selectStaffRecord(found);
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Selected Staff Summary Card
  Widget _buildSelectedStaffSummaryCard(bool isDark) {
    final staff = _selectedStaffRecord;
    final staffName = staff?['full_name']?.toString() ?? 'No Staff Selected';
    final empId = staff?['employee_id']?.toString() ?? 'EMP-001';
    final designation = staff?['designation']?.toString() ?? 'Faculty Member';
    final department = staff?['department']?.toString() ?? 'Academic & Teaching';
    final payoutStatus = staff?['payout_status']?.toString() ?? 'Pending';
    final isAlreadyPaid = payoutStatus == 'Paid';
    final payslipNo = staff?['payout_payslip_number']?.toString() ?? '';
    final txnRef = staff?['payout_txn_ref']?.toString() ?? '';
    final netPay = (staff?['payout_net_pay'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlreadyPaid
              ? const Color(0xFF16A34A).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
                child: Text(
                  staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$designation • $department',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Period Status Badge
              Builder(
                builder: (ctx) {
                  final isOnHold = payoutStatus == 'On Hold' || payoutStatus == 'On-Hold';
                  final bColor = isAlreadyPaid
                      ? const Color(0xFF16A34A)
                      : isOnHold
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF59E0B);
                  final bIcon = isAlreadyPaid
                      ? Icons.check_circle_rounded
                      : isOnHold
                          ? Icons.pause_circle_rounded
                          : Icons.pending_actions_rounded;
                  final bLabel = isAlreadyPaid
                      ? 'Paid for $_selectedMonthStr'
                      : isOnHold
                          ? 'On Hold for $_selectedMonthStr'
                          : 'Pending for $_selectedMonthStr';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: bColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: bColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(bIcon, size: 14, color: bColor),
                        const SizedBox(width: 5),
                        Text(
                          bLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: bColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Metadata Chips
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildBadge(Icons.badge_rounded, 'EMP: $empId', isDark),
              _buildBadge(Icons.credit_card_rounded, 'PAN: ${_panNumberController.text.isNotEmpty ? _panNumberController.text : "ABCDE1234F"}', isDark),
              _buildBadge(
                Icons.account_balance_rounded,
                '${_bankNameController.text.isNotEmpty ? _bankNameController.text : "Bank"} • ${_accountNumberController.text.length > 4 ? "••${_accountNumberController.text.substring(_accountNumberController.text.length - 4)}" : "Registered"}',
                isDark,
              ),
            ],
          ),

          // Already Paid Callout Notice
          if (isAlreadyPaid) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Disbursed: ₹ ${netPay != null ? NumberFormat('#,##,###').format(netPay.toInt()) : "57,890"}  |  Payslip: ${payslipNo.isNotEmpty ? payslipNo : "PS-$_selectedMonthStr-$empId"}  |  UTR: ${txnRef.isNotEmpty ? txnRef : "Registered"}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
        ],
      ),
    );
  }

  // Active Loans & Advances Recovery Card
  Widget _buildActiveLoansCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Loan Advances: ${_activeLoanCount > 0 ? "$_activeLoanCount Loans Approved" : "Active Balance"}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                ),
              ),
              if (_loadingStaffDetail)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Outstanding Debt', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text(
                      '₹ ${NumberFormat('#,##,###').format(_totalOutstandingLoans.toInt())}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Scheduled Monthly EMI', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text(
                      '₹ ${NumberFormat('#,##,###').format(_standardMonthlyLoanEmi.toInt())}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
              // EMI Recovery Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recover EMI',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _recoverLoanEmi,
                      activeThumbColor: const Color(0xFF16A34A),
                      activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.5),
                      onChanged: (val) {
                        setState(() {
                          _recoverLoanEmi = val;
                          if (val) {
                            _advanceDeductionController.text = _standardMonthlyLoanEmi.toInt().toString();
                          } else {
                            _advanceDeductionController.text = '0';
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_activeLoans.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _activeLoans.map((adv) {
                final purpose = adv['purpose_type']?.toString() ?? 'Loan';
                final amt = (adv['amount'] as num?)?.toDouble() ?? 0.0;
                final repaid = (adv['amount_repaid'] as num?)?.toDouble() ?? 0.0;
                final bal = amt - repaid;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$purpose: ₹${NumberFormat('#,##,###').format(bal.toInt())} balance',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '✓ Deducted loan amount is automatically credited to the oldest active loan (FIFO) under EduSHAMIIT Ledger.',
            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLoansCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No active salary advances or outstanding loans found for this staff member.',
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  // Two-Column Financial Computation Grid with Variable Bonus & Deductions Engine
  Widget _buildFinancialGrid(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column 1: Gross Earnings (Green Palette)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'EARNINGS & ALLOWANCES',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                    ),
                    Text(
                      '₹ ${NumberFormat('#,##,###').format(_gross.toInt())}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _buildNumberInput('Basic Pay (₹)', _basicPayController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('House Rent Allowance (HRA)', _hraController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Dearness Allowance (DA)', _daController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Travel Allowance (TA)', _taController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Special Allowance', _allowanceController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Medical Allowance', _medicalController, isDark),
                const SizedBox(height: 12),

                // Variable Performance Bonus Section
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'VARIABLE BONUS & INCENTIVES',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                          ),
                          Text(
                            'Resets Monthly',
                            style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildNumberInput('Bonus Amount (₹)', _bonusController, isDark),
                      const SizedBox(height: 6),
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _bonusType,
                        decoration: InputDecoration(
                          labelText: 'Bonus Classification',
                          labelStyle: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        items: _bonusTypeOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt['value'],
                            child: Text(opt['label']!, style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _bonusType = val);
                        },
                      ),
                      const SizedBox(height: 6),
                      _buildTextInput('Bonus Notes / Achievement Metric', _bonusRemarksController, isDark, hint: 'e.g. Q2 target achievement, Diwali ex-gratia'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Column 2: Deductions & Recoveries (Rose/Red Palette)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DEDUCTIONS & RECOVERIES',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                    ),
                    Text(
                      '- ₹ ${NumberFormat('#,##,###').format(_deductions.toInt())}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                _buildNumberInput('Provident Fund (PF) (₹)', _pfController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('TDS / Income Tax', _tdsController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Professional Tax (PTax)', _ptaxController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Insurance / ESI', _insuranceController, isDark),
                const SizedBox(height: 8),
                _buildNumberInput('Advance Loan Recovery (EMI)', _advanceDeductionController, isDark, highlight: _hasActiveLoans),
                const SizedBox(height: 12),

                // Variable Ad-hoc Deductions Section
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ONE-OFF AD-HOC DEDUCTIONS',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                          Text(
                            'Resets Monthly',
                            style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildNumberInput('Loss of Pay / Damage (₹)', _otherDeductionsController, isDark),
                      const SizedBox(height: 6),
                      _buildTextInput('Deduction Reason / Notes', _otherDeductionsRemarksController, isDark, hint: 'e.g. 2 days unpaid leave (LOP), key replacement'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Permanent Structure Update Card (Contract / Increment)
  Widget _buildPermanentStructureUpdateCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _updatePermanentStructure
            ? const Color(0xFF3B82F6).withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _updatePermanentStructure
              ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _updatePermanentStructure,
            activeColor: const Color(0xFF3B82F6),
            onChanged: (val) => setState(() => _updatePermanentStructure = val ?? false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update Employee Base Contract Structure (Increment / CTC Revision)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _updatePermanentStructure
                        ? const Color(0xFF3B82F6)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saves base pay and statutory allowances into permanent employee record for future cycles. Variable bonus and ad-hoc deductions automatically reset.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Executive Net Pay Callout Banner
  Widget _buildNetPayBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF16A34A), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NET TAKE-HOME PAYABLE FOR $_selectedMonthStr',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gross Earnings (₹ ${NumberFormat('#,##,###').format(_gross.toInt())})  -  Deductions (₹ ${NumberFormat('#,##,###').format(_deductions.toInt())})',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
            ),
            child: Text(
              '₹ ${NumberFormat('#,##,###').format(_net.toInt())}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Payment Routing & Banking Tender Card
  Widget _buildPaymentRoutingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Disbursement Tender & Banking Channel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          // Payment Mode Selector
          Builder(
            builder: (context) {
              final availableModes = _paymentModes.isNotEmpty
                  ? _paymentModes.map((m) => m.label).toSet().toList()
                  : [
                      'Direct Bank Transfer (NEFT/RTGS)',
                      'Corporate UPI / VPA',
                      'Corporate Cheque',
                      'Cash Voucher',
                    ];
              if (!availableModes.contains(_paymentMode)) {
                availableModes.insert(0, _paymentMode);
              }

              return AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: _paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment Mode',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                items: availableModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Mode-specific fields
          if (_paymentMode.contains('Bank') || _paymentMode.contains('NEFT')) ...[
            Row(
              children: [
                Expanded(child: _buildTextInput('Staff Bank Name', _bankNameController, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextInput('Account Number', _accountNumberController, isDark)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTextInput('IFSC Code', _ifscController, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextInput('UTR / Transaction Ref', _txnRefController, isDark)),
              ],
            ),
          ] else if (_paymentMode.contains('UPI')) ...[
            Row(
              children: [
                Expanded(child: _buildTextInput('Recipient UPI ID / VPA', _upiIdController, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextInput('UTR / UPI Ref Number', _txnRefController, isDark)),
              ],
            ),
          ] else if (_paymentMode.contains('Cheque')) ...[
            Row(
              children: [
                Expanded(child: _buildTextInput('Cheque Number', _chequeNoController, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextInput('Issuing Bank', _bankNameController, isDark)),
              ],
            ),
          ] else ...[
            _buildTextInput('Authorized Cashier Desk', _cashierController, isDark),
          ],
        ],
      ),
    );
  }

  // Authorization Status & Audit Remarks
  Widget _buildAuthorizationSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Disbursal Status & Execution Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Row(
                children: ['Paid', 'Pending', 'On Hold'].map((st) {
                  final isSel = _payoutStatus == st;
                  Color col = const Color(0xFF16A34A);
                  if (st == 'Pending') col = const Color(0xFFF59E0B);
                  if (st == 'On Hold') col = const Color(0xFFDC2626);

                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () => setState(() => _payoutStatus = st),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? col : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isSel ? col : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                        ),
                        child: Text(
                          st,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextInput('Internal Audit Notes / Remarks', _remarksController, isDark, hint: 'Optional disbursal remarks or ledger references'),
        ],
      ),
    );
  }

  // Bottom Action Buttons
  Widget _buildBottomActionButtons(bool isDark) {
    final isAlreadyPaid = _selectedStaffRecord?['payout_status']?.toString() == 'Paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Authorized by Finance Department • SSOT',
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
          Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _payoutStatus == 'Paid'
                      ? const Color(0xFF16A34A)
                      : _payoutStatus == 'On Hold'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                ),
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _payoutStatus == 'Paid'
                            ? Icons.send_rounded
                            : _payoutStatus == 'On Hold'
                                ? Icons.pause_circle_filled_rounded
                                : Icons.save_rounded,
                        size: 16,
                      ),
                label: Text(
                  _submitting
                      ? 'Processing...'
                      : _payoutStatus == 'Paid'
                          ? (isAlreadyPaid ? 'Update Disbursal (₹ ${NumberFormat('#,##,###').format(_net.toInt())})' : 'Disburse & Authorize (₹ ${NumberFormat('#,##,###').format(_net.toInt())})')
                          : _payoutStatus == 'On Hold'
                              ? 'Place Payout On Hold (₹ ${NumberFormat('#,##,###').format(_net.toInt())})'
                              : 'Save as Pending (₹ ${NumberFormat('#,##,###').format(_net.toInt())})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput(String label, TextEditingController controller, bool isDark, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: highlight ? const Color(0xFFF59E0B) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildTextInput(String label, TextEditingController controller, bool isDark, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedStaffId == null) {
      setState(() => _errorMessage = 'Please select a staff member first.');
      return;
    }
    final bpay = double.tryParse(_basicPayController.text.trim()) ?? 0.0;
    if (bpay <= 0) {
      setState(() => _errorMessage = 'Basic Pay must be greater than zero.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final parts = _selectedMonthStr.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final month = int.tryParse(parts[1]) ?? 10;

    final staff = _selectedStaffRecord;
    final staffName = staff?['full_name']?.toString() ?? 'Employee';
    final empId = staff?['employee_id']?.toString() ?? 'EMP-001';
    final designation = staff?['designation']?.toString() ?? 'Faculty';
    final department = staff?['department']?.toString() ?? 'Academic';

    final payload = {
      'staff_id': _selectedStaffId,
      'month': month,
      'year': year,
      'month_str': _selectedMonthStr,
      'basic_pay': bpay,
      'hra': double.tryParse(_hraController.text) ?? 0,
      'da': double.tryParse(_daController.text) ?? 0,
      'ta': double.tryParse(_taController.text) ?? 0,
      'special_allowance': double.tryParse(_allowanceController.text) ?? 0,
      'medical_allowance': double.tryParse(_medicalController.text) ?? 0,
      'bonus': double.tryParse(_bonusController.text) ?? 0,
      'bonus_type': _bonusType,
      'bonus_remarks': _bonusRemarksController.text.trim().isNotEmpty ? _bonusRemarksController.text.trim() : null,
      'pf_deduction': double.tryParse(_pfController.text) ?? 0,
      'tds': double.tryParse(_tdsController.text) ?? 0,
      'professional_tax': double.tryParse(_ptaxController.text) ?? 0,
      'insurance_deduction': double.tryParse(_insuranceController.text) ?? 0,
      'advance_deduction': double.tryParse(_advanceDeductionController.text) ?? 0,
      'other_deductions': double.tryParse(_otherDeductionsController.text) ?? 0,
      'other_deductions_remarks': _otherDeductionsRemarksController.text.trim().isNotEmpty ? _otherDeductionsRemarksController.text.trim() : null,
      'payment_status': _payoutStatus,
      'payment_mode': _paymentMode,
      'transaction_reference': _txnRefController.text.trim(),
      'remarks': _remarksController.text.trim(),
      'bank_name': _bankNameController.text.trim(),
      'account_number': _accountNumberController.text.trim(),
      'ifsc_code': _ifscController.text.trim(),
      'pan_number': _panNumberController.text.trim(),
      'update_permanent_structure': _updatePermanentStructure,
    };

    final result = await PaymentManagementApiService.instance.processStaffPayout(payload);

    if (mounted) {
      setState(() => _submitting = false);
      if (result['success'] == true) {
        Navigator.of(context).pop();
        ref.read(staffSalaryProvider.notifier).loadAllData();

        final payoutData = (result['payout'] ?? result['data']) as Map<String, dynamic>?;
        final payslipNumber = payoutData?['payslip_number']?.toString() ?? 'PS-$_selectedMonthStr-$empId';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Salary of ₹ ${NumberFormat('#,##,###').format(_net.toInt())} for $staffName disbursed successfully! Loan balance and ledger synchronized.',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Open Payslip Preview immediately for Instant Print / Download
        showDialog(
          context: context,
          builder: (ctx) => StaffPayslipDialog(
            payslip: {
              'staff_name': staffName,
              'employee_id': empId,
              'designation': designation,
              'department': department,
              'payslip_number': payslipNumber,
              'month_str': _selectedMonthStr,
              'basic_pay': bpay,
              'hra': double.tryParse(_hraController.text) ?? 0,
              'da': double.tryParse(_daController.text) ?? 0,
              'ta': double.tryParse(_taController.text) ?? 0,
              'special_allowance': double.tryParse(_allowanceController.text) ?? 0,
              'medical_allowance': double.tryParse(_medicalController.text) ?? 0,
              'bonus': double.tryParse(_bonusController.text) ?? 0,
              'bonus_type': _bonusType,
              'bonus_remarks': _bonusRemarksController.text.trim(),
              'pf_deduction': double.tryParse(_pfController.text) ?? 0,
              'tds': double.tryParse(_tdsController.text) ?? 0,
              'professional_tax': double.tryParse(_ptaxController.text) ?? 200,
              'insurance_deduction': double.tryParse(_insuranceController.text) ?? 0,
              'advance_deduction': double.tryParse(_advanceDeductionController.text) ?? 0,
              'other_deductions': double.tryParse(_otherDeductionsController.text) ?? 0,
              'net_pay': _net,
              'payment_mode': _paymentMode,
              'transaction_reference': _txnRefController.text.trim(),
              'bank_name': _bankNameController.text.trim(),
              'account_number': _accountNumberController.text.trim(),
              'ifsc_code': _ifscController.text.trim(),
              'pan_number': _panNumberController.text.trim(),
            },
          ),
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to disburse salary. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result['message'] ?? 'Disbursal failed. Please check parameters.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
