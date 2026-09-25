import 'dart:math';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class AddCandidateDialog extends StatefulWidget {
  final VoidCallback onCandidateAdded;
  final String? preselectedJobId;

  const AddCandidateDialog({
    super.key,
    required this.onCandidateAdded,
    this.preselectedJobId,
  });

  @override
  State<AddCandidateDialog> createState() => _AddCandidateDialogState();
}

class _AddCandidateDialogState extends State<AddCandidateDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _qualificationController = TextEditingController(text: 'M.Sc., B.Ed.');
  final TextEditingController _specializationController = TextEditingController(text: 'Physics');
  final TextEditingController _experienceController = TextEditingController(text: '3.5');
  final TextEditingController _currentOrgController = TextEditingController(text: 'DPS Delhi');
  final TextEditingController _currentDesignationController = TextEditingController(text: 'Assistant Teacher');
  final TextEditingController _expectedSalaryController = TextEditingController(text: '55000');
  final TextEditingController _noticePeriodController = TextEditingController(text: '30');
  final TextEditingController _skillsController = TextEditingController(text: 'CBSE Curriculum, Lab Sessions, Student Counseling');
  final TextEditingController _notesController = TextEditingController();

  String? _selectedJobId;
  String _source = 'Website';
  bool _isLoadingJobs = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _availableJobs = [];

  List<String> _sources = HRLookupHelper.instance.getCachedLabels('RECRUITMENT_SOURCE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _selectedJobId = widget.preselectedJobId;
    _fetchJobs();
    _loadSources(true);
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadSources(true);
    }
  }

  Future<void> _loadSources([bool forceRefresh = true]) async {
    final sources = await HRLookupHelper.instance.getLookupLabels('RECRUITMENT_SOURCE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _sources = sources;
        if (!_sources.contains(_source) && _sources.isNotEmpty) {
          _source = _sources.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _currentOrgController.dispose();
    _currentDesignationController.dispose();
    _expectedSalaryController.dispose();
    _noticePeriodController.dispose();
    _skillsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoadingJobs = true);
    try {
      final res = await _apiService.get('/recruitment/jobs?publishing_status=Active&limit=500');
      final List items = res['data'] ?? res['items'] ?? [];
      setState(() {
        _availableJobs = items.map((e) => Map<String, dynamic>.from(e)).toList();
        if (_selectedJobId == null && _availableJobs.isNotEmpty) {
          _selectedJobId = _availableJobs.first['id'].toString();
        }
      });
    } catch (e) {
      debugPrint('Failed to load active jobs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _submitCandidate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final skillsList = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final exp = double.tryParse(_experienceController.text.trim()) ?? 0.0;
      final expSal = double.tryParse(_expectedSalaryController.text.trim());
      final notice = int.tryParse(_noticePeriodController.text.trim()) ?? 0;
      final randCode = 1000 + Random().nextInt(9000);

      final payload = {
        'candidate_code': 'CAN-$randCode',
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'qualification': _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
        'specialization': _specializationController.text.trim().isEmpty ? null : _specializationController.text.trim(),
        'experience_years': exp,
        'current_organization': _currentOrgController.text.trim().isEmpty ? null : _currentOrgController.text.trim(),
        'current_designation': _currentDesignationController.text.trim().isEmpty ? null : _currentDesignationController.text.trim(),
        'expected_salary': expSal,
        'notice_period_days': notice,
        'skills': skillsList,
        'source': _source,
        'job_id': _selectedJobId,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await _apiService.post('/recruitment/candidates', payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Candidate ${_nameController.text.trim()} added successfully to Applied pipeline!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onCandidateAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add New Candidate Application',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          'Enter applicant details and link with an active job vacancy',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
              const Divider(height: 24),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Job Linking
                      const Text('1. Position & Application Source', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _isLoadingJobs
                                ? const Center(child: LinearProgressIndicator())
                                : DropdownButtonFormField<String>(
                                    initialValue: _selectedJobId,
                                    decoration: const InputDecoration(
                                      labelText: 'Target Job Opening *',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    items: _availableJobs.map((j) {
                                      return DropdownMenuItem<String>(
                                        value: j['id'].toString(),
                                        child: Text(
                                          '${j['job_title']} (${j['department']})',
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedJobId = val),
                                    validator: (val) => val == null ? 'Please select a job' : null,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _sources.contains(_source) ? _source : (_sources.isNotEmpty ? _sources.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Application Source',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _source = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Personal Information
                      const Text('2. Personal & Contact Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline, size: 20),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined, size: 20),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Email is required';
                                if (!val.contains('@')) return 'Invalid email format';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Experience & Qualifications
                      const Text('3. Qualifications & Experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qualificationController,
                              decoration: const InputDecoration(
                                labelText: 'Qualification',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _specializationController,
                              decoration: const InputDecoration(
                                labelText: 'Specialization / Subject',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _experienceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Experience (Years)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _currentOrgController,
                              decoration: const InputDecoration(
                                labelText: 'Current Organization',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _currentDesignationController,
                              decoration: const InputDecoration(
                                labelText: 'Current Designation',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expectedSalaryController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Expected Salary (₹ / month)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _noticePeriodController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Notice Period (Days)',
                                suffixText: 'Days',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _skillsController,
                        decoration: const InputDecoration(
                          labelText: 'Key Skills (comma separated)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Recruiter Notes',
                          hintText: 'Any initial assessment or observations...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitCandidate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Saving...' : 'Add Candidate',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
