import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'package:intl/intl.dart';

class StartOnboardingDialog extends StatefulWidget {
  final VoidCallback onOnboardingCreated;

  const StartOnboardingDialog({
    super.key,
    required this.onOnboardingCreated,
  });

  @override
  State<StartOnboardingDialog> createState() => _StartOnboardingDialogState();
}

class _StartOnboardingDialogState extends State<StartOnboardingDialog> {
  final ApiService _api = ApiService();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: Candidate selection
  List<dynamic> _eligibleCandidates = [];
  bool _isSearchingCandidates = false;
  Map<String, dynamic>? _selectedCandidate;

  // Step 2: Joining info
  final _formKey = GlobalKey<FormState>();
  DateTime _expectedJoiningDate = DateTime.now().add(const Duration(days: 7));
  final TextEditingController _timeController = TextEditingController(text: '09:00 AM');
  final TextEditingController _locationController = TextEditingController(text: 'Main Campus - HR Dept');
  String _selectedDepartment = 'Academics';
  final TextEditingController _designationController = TextEditingController(text: 'Teacher');
  String _selectedEmploymentType = 'Full-time';
  int _probationPeriodMonths = 6;
  final TextEditingController _workLocationController = TextEditingController(text: 'Main Campus');
  final TextEditingController _shiftController = TextEditingController(text: 'General Shift');
  final TextEditingController _notesController = TextEditingController();

  // Step 3: Template selection
  List<dynamic> _templates = [];
  String _selectedTemplateName = 'Teaching Staff Onboarding';

  List<String> _departments = HRLookupHelper.instance.getCachedLabels('DEPARTMENT');
  List<String> _employmentTypes = HRLookupHelper.instance.getCachedLabels('EMPLOYMENT_TYPE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _fetchEligibleCandidates();
    _fetchTemplates();
    _loadLookups(true);
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final types = await HRLookupHelper.instance.getLookupLabels('EMPLOYMENT_TYPE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departments = depts;
        if (!_departments.contains(_selectedDepartment) && _departments.isNotEmpty) {
          _selectedDepartment = _departments.first;
        }
        _employmentTypes = types;
        if (!_employmentTypes.contains(_selectedEmploymentType) && _employmentTypes.isNotEmpty) {
          _selectedEmploymentType = _employmentTypes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _timeController.dispose();
    _locationController.dispose();
    _designationController.dispose();
    _workLocationController.dispose();
    _shiftController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchEligibleCandidates({String? query}) async {
    setState(() => _isSearchingCandidates = true);
    try {
      final res = await _api.get(
        '/onboarding/candidates/eligible',
        query: query != null && query.isNotEmpty ? {'search': query} : null,
        useCache: false,
      );
      if (res['success'] == true) {
        setState(() {
          _eligibleCandidates = res['data'] as List<dynamic>? ?? [];
          _isSearchingCandidates = false;
        });
      } else {
        setState(() => _isSearchingCandidates = false);
      }
    } catch (_) {
      setState(() => _isSearchingCandidates = false);
    }
  }

  Future<void> _fetchTemplates() async {
    try {
      final res = await _api.get('/onboarding/templates', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _templates = res['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  void _onCandidateSelected(Map<String, dynamic> cand) {
    setState(() {
      _selectedCandidate = cand;
      if (cand['department'] != null && cand['department'].toString().isNotEmpty) {
        if (_departments.contains(cand['department'])) {
          _selectedDepartment = cand['department'];
        }
      }
      if (cand['job_title'] != null && cand['job_title'].toString().isNotEmpty) {
        _designationController.text = cand['job_title'];
      } else if (cand['current_designation'] != null) {
        _designationController.text = cand['current_designation'];
      }

      // Automatically select appropriate template
      if (_selectedDepartment == 'Academics') {
        _selectedTemplateName = 'Teaching Staff Onboarding';
      } else if (_selectedDepartment == 'Administration') {
        _selectedTemplateName = 'Administrative Staff Onboarding';
      } else if (_selectedDepartment == 'IT / Technical') {
        _selectedTemplateName = 'IT & Technical Staff Onboarding';
      } else if (_selectedDepartment == 'Transport') {
        _selectedTemplateName = 'Transport & Support Staff Onboarding';
      }
    });
  }

  Future<void> _submitOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final payload = {
      'candidate_id': _selectedCandidate?['id'],
      'department': _selectedDepartment,
      'designation': _designationController.text.trim(),
      'employment_type': _selectedEmploymentType,
      'expected_joining_date': DateFormat('yyyy-MM-dd').format(_expectedJoiningDate),
      'reporting_time': _timeController.text.trim(),
      'reporting_location': _locationController.text.trim(),
      'probation_period_months': _probationPeriodMonths,
      'work_location': _workLocationController.text.trim(),
      'shift': _shiftController.text.trim(),
      'template_name': _selectedTemplateName,
      'notes': _notesController.text.trim(),
    };

    try {
      final res = await _api.post('/onboarding/records', payload);
      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.onOnboardingCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Onboarding started successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to create onboarding record.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start New Onboarding',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Initiate candidate induction, configure tasks, assign templates & set joining dates.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Stepper indicator
            _buildStepper(isDark),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                child: _buildCurrentStepContent(isDark),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Bottom Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_currentStep < 3) {
                                if (_currentStep == 0 && _selectedCandidate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select a candidate or proceed as new hire.')),
                                  );
                                }
                                setState(() => _currentStep++);
                              } else {
                                _submitOnboarding();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_currentStep == 3 ? 'Start Onboarding' : 'Next Step →'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(bool isDark) {
    final steps = ['Select Candidate', 'Joining Info', 'Template', 'Confirm'];
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isPassed = index < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPassed
                      ? const Color(0xFF10B981)
                      : (isActive ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                ),
                child: Center(
                  child: isPassed
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: isPassed ? const Color(0xFF10B981) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Candidate(isDark);
      case 1:
        return _buildStep2JoiningInfo(isDark);
      case 2:
        return _buildStep3Template(isDark);
      case 3:
        return _buildStep4Review(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Candidate Selection from Recruitment
  Widget _buildStep1Candidate(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Candidate from Recruitment',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (_selectedCandidate != null)
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Clear Selection'),
                onPressed: () => setState(() => _selectedCandidate = null),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Search candidate box
        TextField(
          decoration: InputDecoration(
            hintText: 'Search candidate by name, code or email...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onChanged: (val) => _fetchEligibleCandidates(query: val),
        ),
        const SizedBox(height: 14),

        if (_isSearchingCandidates)
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_eligibleCandidates.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No eligible candidates found. You can proceed without candidate link as a direct hire.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          )
        else
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                itemCount: _eligibleCandidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final cand = _eligibleCandidates[idx];
                  final isSelected = _selectedCandidate?['id'] == cand['id'];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    child: Text(
                      cand['full_name'] != null && cand['full_name'].toString().isNotEmpty
                          ? cand['full_name'][0].toUpperCase()
                          : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  title: Text(
                    cand['full_name'] ?? 'Unknown Candidate',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  subtitle: Text(
                    '${cand['candidate_code']} • ${cand['job_title'] ?? cand['current_designation'] ?? 'Candidate'} (${cand['department'] ?? 'General'})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5), size: 20)
                      : OutlinedButton(
                          onPressed: () => _onCandidateSelected(cand),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: const Text('Select', style: TextStyle(fontSize: 11)),
                        ),
                  onTap: () => _onCandidateSelected(cand),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // STEP 2: Joining Information Form
  Widget _buildStep2JoiningInfo(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Department *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _departments.contains(_selectedDepartment) ? _selectedDepartment : (_departments.isNotEmpty ? _departments.first : null),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDepartment = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Designation / Role *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _designationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Physics Teacher, Accountant',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Employment Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _employmentTypes.contains(_selectedEmploymentType) ? _selectedEmploymentType : (_employmentTypes.isNotEmpty ? _employmentTypes.first : null),
                      items: _employmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedEmploymentType = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expected Joining Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _expectedJoiningDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _expectedJoiningDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_expectedJoiningDate),
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reporting Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _timeController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reporting Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Probation Period (Months)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<int>.fromMenuItems(
                      initialValue: _probationPeriodMonths,
                      items: [3, 6, 9, 12].map((m) => DropdownMenuItem(value: m, child: Text('$m Months'))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _probationPeriodMonths = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shift Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _shiftController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 3: Onboarding Checklist Template
  Widget _buildStep3Template(bool isDark) {
    return RadioGroup<String>(
      groupValue: _selectedTemplateName,
      onChanged: (val) {
        if (val != null) setState(() => _selectedTemplateName = val);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Onboarding Checklist Template',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Predefined tasks and required documents will automatically attach to this employee record.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          ..._templates.map((tmpl) {
            final isSelected = _selectedTemplateName == tmpl['name'];
            final tasks = tmpl['default_tasks'] as List<dynamic>? ?? [];
            final docs = tmpl['default_documents'] as List<dynamic>? ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
                    : (isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4F46E5)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedTemplateName = tmpl['name']),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: tmpl['name'],
                    ),
                    const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tmpl['name'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF4F46E5) : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tmpl['department'] ?? 'General',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tmpl['description'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.checklist_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${tasks.length} Default Tasks', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 14),
                            Icon(Icons.description_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text('${docs.length} Required Documents', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    ),
  );
}

  // STEP 4: Review & Summary
  Widget _buildStep4Review(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Confirm Onboarding Launch',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildReviewRow('Candidate Name', _selectedCandidate?['full_name'] ?? 'Direct New Hire'),
              _buildReviewRow('Candidate Code / ID', _selectedCandidate?['candidate_code'] ?? 'New Hire Record'),
              _buildReviewRow('Email', _selectedCandidate?['email'] ?? 'Not provided'),
              const Divider(height: 16),
              _buildReviewRow('Department', _selectedDepartment),
              _buildReviewRow('Designation', _designationController.text),
              _buildReviewRow('Employment Type', _selectedEmploymentType),
              _buildReviewRow('Expected Joining Date', DateFormat('dd MMMM yyyy').format(_expectedJoiningDate)),
              _buildReviewRow('Reporting Time & Place', '${_timeController.text} at ${_locationController.text}'),
              _buildReviewRow('Probation Period', '$_probationPeriodMonths Months'),
              const Divider(height: 16),
              _buildReviewRow('Onboarding Checklist Template', _selectedTemplateName),
              _buildReviewRow('Initial Stage', 'Offer Accepted'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
