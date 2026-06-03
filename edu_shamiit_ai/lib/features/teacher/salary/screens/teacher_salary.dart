import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class TeacherSalary extends ConsumerStatefulWidget {
  const TeacherSalary({super.key});

  @override
  ConsumerState<TeacherSalary> createState() => _TeacherSalaryState();
}

class _TeacherSalaryState extends ConsumerState<TeacherSalary> {
  final TeacherApiService _apiService = TeacherApiService();
  
  List<SalarySlip> _salarySlips = [];
  List<SalaryAdvance> _advanceRequests = [];
  bool _isLoading = true;
  bool _isLoadingAdvances = false;
  String? _error;
  int _selectedSlipIndex = 0;
  int _activeTab = 0; // 0: Payslips, 1: Salary Advance

  // Month Picker Selection
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Salary Advance Form States
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  String _selectedPurpose = 'medical_purpose';
  int _advanceMonth = DateTime.now().month;
  int _advanceYear = DateTime.now().year;
  bool _isSubmittingAdvance = false;

  final List<String> _monthNames = [
    "", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  final List<Map<String, String>> _purposes = [
    {'value': 'medical_purpose', 'label': 'Medical Purpose'},
    {'value': 'relocation', 'label': 'Relocation'},
    {'value': 'personal_urgency', 'label': 'Personal Urgency'},
    {'value': 'other', 'label': 'Other (Specify Reason)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final slips = await _apiService.getSalarySlips();
      final advances = await _apiService.getSalaryAdvances();
      
      setState(() {
        _salarySlips = slips;
        _advanceRequests = advances;
        
        if (slips.isNotEmpty) {
          _selectedSlipIndex = 0;
          _selectedMonth = slips[0].month;
          _selectedYear = slips[0].year;
          
          // Default advance request month to next month or current month
          _advanceMonth = slips[0].month;
          _advanceYear = slips[0].year;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSalarySlips() async {
    try {
      final slips = await _apiService.getSalarySlips();
      setState(() {
        _salarySlips = slips;
        _updateSelectedSlipIndex();
      });
    } catch (e) {
      // silent fail or log
    }
  }

  Future<void> _loadAdvanceRequests() async {
    setState(() {
      _isLoadingAdvances = true;
    });
    try {
      final advances = await _apiService.getSalaryAdvances();
      setState(() {
        _advanceRequests = advances;
        _isLoadingAdvances = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAdvances = false;
      });
    }
  }

  void _updateSelectedSlipIndex() {
    final idx = _salarySlips.indexWhere((slip) => slip.month == _selectedMonth && slip.year == _selectedYear);
    setState(() {
      _selectedSlipIndex = idx;
    });
  }

  Future<void> _downloadSlip(SalarySlip slip) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📄 Downloading payslip for ${_monthNames[slip.month]} ${slip.year}...'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      final token = await _apiService.getAuthToken();
      final url = '${AppConfig.apiBaseUrl}/teacher/salary/${slip.id}/download?token=$token';
      
      await getDownloadHelper().downloadFile(url, 'Payslip_${slip.year}_${_monthNames[slip.month]}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Download failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _submitAdvanceRequest(double limit) async {
    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      _showSnackBar('Please enter a valid amount greater than zero', Colors.red);
      return;
    }
    if (amt > limit) {
      _showSnackBar('Requested amount exceeds the maximum allowable limit of Rs. ${limit.toStringAsFixed(2)}', Colors.red);
      return;
    }
    if (_selectedPurpose == 'other' && _reasonController.text.trim().isEmpty) {
      _showSnackBar('Please provide a reason for the advance request', Colors.red);
      return;
    }

    setState(() {
      _isSubmittingAdvance = true;
    });

    try {
      await _apiService.requestSalaryAdvance(
        amount: amt,
        purposeType: _selectedPurpose,
        reason: _selectedPurpose == 'other' ? _reasonController.text.trim() : null,
        month: _advanceMonth,
        year: _advanceYear,
      );
      _showSnackBar('✔ Salary advance request submitted successfully!', Colors.green);
      _amountController.clear();
      _reasonController.clear();
      await _loadAdvanceRequests();
      await _loadSalarySlips();
    } catch (e) {
      _showSnackBar('❌ Request failed: ${e.toString().replaceAll('Exception:', '')}', Colors.red);
    } finally {
      setState(() {
        _isSubmittingAdvance = false;
      });
    }
  }

  Future<void> _simulateApproval(String advanceId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Simulating admin approval...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 800),
        ),
      );
      await _apiService.simulateAdvanceApproval(advanceId);
      _showSnackBar('✔ Salary advance approved! Funds transferred and deducted from salary.', Colors.green);
      await _loadAdvanceRequests();
      await _loadSalarySlips();
    } catch (e) {
      _showSnackBar('❌ Simulation failed: $e', Colors.red);
    }
  }

  Future<void> _cancelAdvanceRequest(String advanceId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Cancelling salary advance request...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 800),
        ),
      );
      await _apiService.cancelSalaryAdvance(advanceId);
      _showSnackBar('✔ Salary advance request cancelled successfully.', Colors.green);
      await _loadAdvanceRequests();
      await _loadSalarySlips();
    } catch (e) {
      _showSnackBar('❌ Cancellation failed: $e', Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${_monthNames[date.month]} ${date.day}, ${date.year}';
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final activeSlip = _salarySlips.isNotEmpty && _selectedSlipIndex >= 0 && _selectedSlipIndex < _salarySlips.length
        ? _salarySlips[_selectedSlipIndex]
        : null;

    // Dynamically calculate mathematically correct details if a slip is selected
    double computedGross = 0.0;
    double computedDeductions = 0.0;
    double computedNet = 0.0;
    double computedHra = 0.0;
    double computedDa = 0.0;
    double computedSa = 0.0;
    double computedPf = 0.0;
    double computedTds = 0.0;
    double computedPt = 0.0;
    double miscEarning = 0.0;
    double miscDeduction = 0.0;
    double advanceDeduction = 0.0;

    if (activeSlip != null) {
      computedHra = activeSlip.hra != 0 ? activeSlip.hra : (activeSlip.allowances * 0.5);
      computedDa = activeSlip.da != 0 ? activeSlip.da : (activeSlip.allowances * 0.3);
      computedSa = activeSlip.specialAllowance != 0 ? activeSlip.specialAllowance : (activeSlip.allowances * 0.2);
      computedPf = activeSlip.pfDeduction != 0 ? activeSlip.pfDeduction : (activeSlip.deductions * 0.5);
      computedTds = activeSlip.tds != 0 ? activeSlip.tds : (activeSlip.deductions * 0.4);
      computedPt = activeSlip.professionalTax != 0 ? activeSlip.professionalTax : (activeSlip.deductions * 0.1);
      miscEarning = activeSlip.miscellaneous > 0 ? activeSlip.miscellaneous : 0.0;
      miscDeduction = activeSlip.miscellaneous < 0 ? -activeSlip.miscellaneous : 0.0;
      advanceDeduction = activeSlip.advanceDeduction;

      computedGross = activeSlip.basicSalary + computedHra + computedDa + computedSa + miscEarning;
      computedDeductions = computedPf + computedTds + computedPt + miscDeduction + advanceDeduction;
      computedNet = computedGross - computedDeductions;
    }

    // Determine basic pay / net salary limit for the selected month to apply to advance form
    double advanceLimit = 0.0;
    final advanceLimitTemplate = _salarySlips.firstWhere(
      (s) => s.month == _advanceMonth && s.year == _advanceYear,
      orElse: () => _salarySlips.isNotEmpty ? _salarySlips[0] : SalarySlip(
        id: '', teacherId: '', teacherName: '', month: 1, year: 2026,
        basicSalary: 45000, allowances: 30000, deductions: 6550, netSalary: 68450,
        createdAt: DateTime.now(), status: 'pending'
      )
    );
    double tHra = advanceLimitTemplate.hra != 0 ? advanceLimitTemplate.hra : (advanceLimitTemplate.allowances * 0.5);
    double tDa = advanceLimitTemplate.da != 0 ? advanceLimitTemplate.da : (advanceLimitTemplate.allowances * 0.3);
    double tSa = advanceLimitTemplate.specialAllowance != 0 ? advanceLimitTemplate.specialAllowance : (advanceLimitTemplate.allowances * 0.2);
    double tPf = advanceLimitTemplate.pfDeduction != 0 ? advanceLimitTemplate.pfDeduction : (advanceLimitTemplate.deductions * 0.5);
    double tTds = advanceLimitTemplate.tds != 0 ? advanceLimitTemplate.tds : (advanceLimitTemplate.deductions * 0.4);
    double tPt = advanceLimitTemplate.professionalTax != 0 ? advanceLimitTemplate.professionalTax : (advanceLimitTemplate.deductions * 0.1);
    double tMiscE = advanceLimitTemplate.miscellaneous > 0 ? advanceLimitTemplate.miscellaneous : 0.0;
    double tMiscD = advanceLimitTemplate.miscellaneous < 0 ? -advanceLimitTemplate.miscellaneous : 0.0;
    double tAdv = advanceLimitTemplate.advanceDeduction;

    double tGross = advanceLimitTemplate.basicSalary + tHra + tDa + tSa + tMiscE;
    double tDeductions = tPf + tTds + tPt + tMiscD + tAdv;
    double tNet = tGross - tDeductions;
    advanceLimit = advanceLimitTemplate.basicSalary < tNet ? advanceLimitTemplate.basicSalary : tNet;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // Light green matching instructions
      body: Column(
        children: [
          // Premium Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Salary Portal',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Sliding Pill Selector for Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeTab == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                'Salary slips',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 0 ? const Color(0xFF065F46) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _activeTab == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                'Salary Advance',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 1 ? const Color(0xFF065F46) : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
            ),

          // Error state
          if (!_isLoading && _error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadAllData,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      child: Text('Retry'.tr(ref), style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),

          // Active Content
          if (!_isLoading && _error == null)
            Expanded(
              child: _activeTab == 0
                  ? _buildPayslipsTab(activeSlip, computedGross, computedDeductions, computedNet, computedHra, computedDa, computedSa, computedPf, computedTds, computedPt, miscEarning, miscDeduction, advanceDeduction)
                  : _buildAdvanceTab(advanceLimit),
            ),
        ],
      ),
    );
  }

  // ================= Payslips Tab Layout =================
  Widget _buildPayslipsTab(
    SalarySlip? activeSlip,
    double computedGross,
    double computedDeductions,
    double computedNet,
    double computedHra,
    double computedDa,
    double computedSa,
    double computedPf,
    double computedTds,
    double computedPt,
    double miscEarning,
    double miscDeduction,
    double advanceDeduction,
  ) {
    return Column(
      children: [
        // Month & Year Picker Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF065F46).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: Color(0xFF059669), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Select Payslip:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)),
              ),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                  items: List.generate(12, (index) {
                    final m = index + 1;
                    return DropdownMenuItem<int>(
                      value: m,
                      child: Text(_monthNames[m]),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMonth = val;
                        _updateSelectedSlipIndex();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                  items: [2025, 2026, 2027].map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text(y.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                        _updateSelectedSlipIndex();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // Horizontal Tabs (Quick selection)
        if (_salarySlips.isNotEmpty)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _salarySlips.length,
              itemBuilder: (context, index) {
                final slip = _salarySlips[index];
                final isSelected = slip.month == _selectedMonth && slip.year == _selectedYear;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSlipIndex = index;
                      _selectedMonth = slip.month;
                      _selectedYear = slip.year;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF059669) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${_monthNames[slip.month].substring(0, 3)} ${slip.year}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        if (activeSlip == null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 54, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    'No payslip found for ${_monthNames[_selectedMonth]} ${_selectedYear}',
                    style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        if (activeSlip != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Net Salary Main Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF065F46).withOpacity(0.06),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Net Salary — ${_monthNames[activeSlip.month]} ${activeSlip.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${_formatAmount(computedNet)}',
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              activeSlip.status.toLowerCase() == 'paid'
                                  ? 'Credited on ${_formatDate(activeSlip.paidAt)}'
                                  : 'Status: ${activeSlip.status.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '₹${_formatAmount(computedGross)}',
                                    style: const TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Text(
                                    'Gross',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '₹${_formatAmount(computedDeductions)}',
                                    style: const TextStyle(
                                      fontFamily: AppFonts.heading,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                  const Text(
                                    'Deductions',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Breakup Section Header
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Breakup',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),

                  // Breakup Table List
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildBreakupRow('Basic Pay', activeSlip.basicSalary),
                        _buildBreakupRow('HRA', computedHra),
                        _buildBreakupRow('DA', computedDa),
                        _buildBreakupRow('Special Allowance', computedSa),
                        
                        // Miscellaneous (if positive, show under earnings breakup)
                        if (miscEarning > 0)
                          _buildBreakupRow('Miscellaneous Earning', miscEarning),
                        
                        _buildBreakupRow('PF Deduction', computedPf, isDeduction: true),
                        _buildBreakupRow('TDS', computedTds, isDeduction: true),
                        _buildBreakupRow('Professional Tax', computedPt, isDeduction: true),
                        
                        // Salary Advance row
                        if (advanceDeduction > 0)
                          _buildBreakupRow('Salary Advance', advanceDeduction, isDeduction: true),
                        
                        // Miscellaneous (if negative, show under deductions breakup)
                        if (miscDeduction > 0)
                          _buildBreakupRow('Miscellaneous Deduction', miscDeduction, isDeduction: true),
                        
                        // Net Salary row Highlight
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Salary',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              Text(
                                '₹${_formatAmount(computedNet)}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Download Button
                  ElevatedButton.icon(
                    onPressed: () => _downloadSlip(activeSlip),
                    icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Download Payslip (PDF)',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF065F46).withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBreakupRow(String label, double value, {bool isDeduction = false}) {
    if (value == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDeduction ? const Color(0xFFEF4444) : const Color(0xFF64748B),
            ),
          ),
          Text(
            '${isDeduction ? "- " : ""}₹${_formatAmount(value)}',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDeduction ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ================= Salary Advance Tab Layout =================
  Widget _buildAdvanceTab(double limit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Request Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF065F46).withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request Salary Advance',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Month/Year Selector for Advance
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Month',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          DropdownButton<int>(
                            value: _advanceMonth,
                            isExpanded: true,
                            style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                            items: List.generate(12, (index) {
                              final m = index + 1;
                              return DropdownMenuItem<int>(
                                value: m,
                                child: Text(_monthNames[m]),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _advanceMonth = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Target Year',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          DropdownButton<int>(
                            value: _advanceYear,
                            isExpanded: true,
                            style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                            items: [2025, 2026, 2027].map((y) {
                              return DropdownMenuItem<int>(
                                value: y,
                                child: Text(y.toString()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _advanceYear = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Purpose Dropdown
                const Text(
                  'Purpose of Advance',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                DropdownButton<String>(
                  value: _selectedPurpose,
                  isExpanded: true,
                  style: const TextStyle(fontFamily: AppFonts.body, color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                  items: _purposes.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['value'],
                      child: Text(p['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPurpose = val;
                      });
                    }
                  },
                ),
                
                if (_selectedPurpose == 'other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Specify Reason',
                      hintText: 'Enter justification...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Amount Field
                const Text(
                  'Requested Amount (INR)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. 10000',
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Dynamic Limit Notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Maximum limit for ${_monthNames[_advanceMonth]} ${_advanceYear}: ₹${_formatAmount(limit)}\n(Minimum of basic pay and net earnings)',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmittingAdvance ? null : () => _submitAdvanceRequest(limit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmittingAdvance
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. History Section Header
          const Text(
            'Request History',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Request History List
          if (_isLoadingAdvances)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Color(0xFF059669)),
              ),
            ),

          if (!_isLoadingAdvances && _advanceRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'No previous salary advance requests found.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            ),

          if (!_isLoadingAdvances && _advanceRequests.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _advanceRequests.length,
              itemBuilder: (context, index) {
                final req = _advanceRequests[index];
                
                // Color configuration by status
                Color statusColor = Colors.orange;
                Color statusBg = const Color(0xFFFFF7ED);
                if (req.status == 'approved') {
                  statusColor = Colors.green;
                  statusBg = const Color(0xFFF0FDF4);
                } else if (req.status == 'rejected') {
                  statusColor = Colors.red;
                  statusBg = const Color(0xFFFEF2F2);
                }

                // Friendly purpose label
                final purposeLabel = _purposes.firstWhere(
                  (p) => p['value'] == req.purposeType,
                  orElse: () => {'label': req.purposeType.replaceRange(0, 1, req.purposeType[0].toUpperCase()).replaceAll('_', ' ')}
                )['label'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            purposeLabel!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              req.status.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount: ₹${_formatAmount(req.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Requested for: ${_monthNames[req.month]} ${req.year}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          Text(
                            'Date: ${_formatDate(req.createdAt)}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      if (req.reason != null && req.reason!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Reason: ${req.reason}',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                        ),
                      ],
                      
                      // Debug Simulate Approval action
                      if (req.status == 'pending') ...[
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _cancelAdvanceRequest(req.id),
                              icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.red),
                              label: const Text(
                                'Cancel Request',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                backgroundColor: const Color(0xFFFEF2F2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _simulateApproval(req.id),
                              icon: const Icon(Icons.flash_on, size: 14, color: Colors.orange),
                              label: const Text(
                                'Simulate Admin Approval (Debug)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                backgroundColor: const Color(0xFFFFFBEB),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
