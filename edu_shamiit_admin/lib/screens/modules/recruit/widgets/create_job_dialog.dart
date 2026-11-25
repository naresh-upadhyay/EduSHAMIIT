import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class CreateJobDialog extends StatefulWidget {
  final VoidCallback onJobCreated;

  const CreateJobDialog({super.key, required this.onJobCreated});

  @override
  State<CreateJobDialog> createState() => _CreateJobDialogState();
}

class _CreateJobDialogState extends State<CreateJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _vacanciesController = TextEditingController(text: '1');
  final TextEditingController _locationController = TextEditingController(text: 'Main Campus');
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _responsibilitiesController = TextEditingController();
  final TextEditingController _qualificationsController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController(text: '2-5 Years');
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _salaryMinController = TextEditingController(text: '35000');
  final TextEditingController _salaryMaxController = TextEditingController(text: '65000');
  final TextEditingController _benefitsController = TextEditingController(text: 'PF, Health Insurance, Transportation Support');

  String _department = 'Academics';
  String _employmentType = 'Full-time';
  final String _payFrequency = 'Monthly';
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  bool _isSubmitting = false;

  // Public Careers Portal Controls
  bool _isPublic = true;
  String _workMode = 'On-site';
  bool _isSalaryPublic = false;
  bool _isFeatured = false;
  List<String> _workModes = HRLookupHelper.instance.getCachedLabels('WORK_MODE');
  List<String> _departments = HRLookupHelper.instance.getCachedLabels('DEPARTMENT');
  List<String> _employmentTypes = HRLookupHelper.instance.getCachedLabels('EMPLOYMENT_TYPE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    final randCode = 100 + Random().nextInt(900);
    _codeController.text = 'JOB-2026-$randCode';
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
    final modes = await HRLookupHelper.instance.getLookupLabels('WORK_MODE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departments = depts;
        if (!_departments.contains(_department) && _departments.isNotEmpty) {
          _department = _departments.first;
        }
        _employmentTypes = types;
        if (!_employmentTypes.contains(_employmentType) && _employmentTypes.isNotEmpty) {
          _employmentType = _employmentTypes.first;
        }
        _workModes = modes;
        if (!_workModes.contains(_workMode) && _workModes.isNotEmpty) {
          _workMode = _workModes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _titleController.dispose();
    _codeController.dispose();
    _designationController.dispose();
    _vacanciesController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _responsibilitiesController.dispose();
    _qualificationsController.dispose();
    _experienceController.dispose();
    _skillsController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    _benefitsController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submitJob({required String status}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final skillsList = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final vacancies = int.tryParse(_vacanciesController.text.trim()) ?? 1;
      final salMin = double.tryParse(_salaryMinController.text.trim());
      final salMax = double.tryParse(_salaryMaxController.text.trim());

      final payload = {
        'job_title': _titleController.text.trim(),
        'job_code': _codeController.text.trim(),
        'department': _department,
        'designation': _designationController.text.trim().isEmpty ? _titleController.text.trim() : _designationController.text.trim(),
        'employment_type': _employmentType,
        'vacancies': vacancies,
        'location': _locationController.text.trim(),
        'campus': 'Main Branch',
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'responsibilities': _responsibilitiesController.text.trim().isEmpty ? null : _responsibilitiesController.text.trim(),
        'required_skills': skillsList,
        'preferred_skills': [],
        'qualifications': _qualificationsController.text.trim().isEmpty ? null : _qualificationsController.text.trim(),
        'experience_required': _experienceController.text.trim(),
        'salary_min': salMin,
        'salary_max': salMax,
        'pay_frequency': _payFrequency,
        'benefits': _benefitsController.text.trim().isEmpty ? null : _benefitsController.text.trim(),
        'application_deadline': DateFormat('yyyy-MM-dd').format(_deadline),
        'publishing_status': status,
        'is_public': _isPublic,
        'work_mode': _workMode,
        'is_salary_public': _isSalaryPublic,
        'is_featured': _isFeatured,
      };

      await _apiService.post('/recruitment/jobs', payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job Opening "${_titleController.text.trim()}" created successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onJobCreated();
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 700,
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
                    child: const Icon(Icons.business_center_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Job Opening',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          'Define role requirements, compensation, and target timeline',
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

              // Form Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Details
                      const Text('1. Position & Department Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Job Title / Role Name *',
                          hintText: 'e.g. Senior Mathematics Teacher (PGT)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter job title' : null,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _departments.contains(_department) ? _department : (_departments.isNotEmpty ? _departments.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Department *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _department = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _employmentTypes.contains(_employmentType) ? _employmentType : (_employmentTypes.isNotEmpty ? _employmentTypes.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Employment Type',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _employmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _employmentType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _vacanciesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Vacancies *',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Required';
                                if (int.tryParse(val) == null || int.parse(val) < 1) return 'Min 1';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Qualifications & Skills
                      const Text('2. Qualifications & Experience', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _qualificationsController,
                              decoration: const InputDecoration(
                                labelText: 'Required Qualifications',
                                hintText: 'e.g. M.Sc, B.Ed or equivalent',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _experienceController,
                              decoration: const InputDecoration(
                                labelText: 'Experience Required',
                                hintText: 'e.g. 2-5 Years',
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
                          labelText: 'Required Skills (comma separated)',
                          hintText: 'e.g. Curriculum Design, Classroom Management, Lab Experiments',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Job Description',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 3: Compensation & Timeline
                      const Text('3. Compensation & Timeline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _salaryMinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Min Salary (₹)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _salaryMaxController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Salary (₹)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: InkWell(
                              onTap: _selectDeadline,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Application Deadline',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.event_outlined, size: 18),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_deadline),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _benefitsController,
                        decoration: const InputDecoration(
                          labelText: 'Benefits & Perks',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section 4: Public Careers Portal Settings
                      const Text('4. Public Careers Portal Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Material(
                        color: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: const Text('Public Visibility', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Publish this job opening on the public /careers portal', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                value: _isPublic,
                                activeThumbColor: const Color(0xFF4F46E5),
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) => setState(() => _isPublic = val),
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                      initialValue: _workModes.contains(_workMode) ? _workMode : (_workModes.isNotEmpty ? _workModes.first : null),
                                      decoration: const InputDecoration(
                                        labelText: 'Work Mode',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      items: _workModes
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _workMode = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: SwitchListTile(
                                      title: const Text('Featured Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Highlight with green Featured pill', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      value: _isFeatured,
                                      activeThumbColor: const Color(0xFF10B981),
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (val) => setState(() => _isFeatured = val),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              SwitchListTile(
                                title: const Text('Display Salary Publicly', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: const Text('Allow candidates to see the salary range on the Careers page', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                value: _isSalaryPublic,
                                activeThumbColor: const Color(0xFF4F46E5),
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) => setState(() => _isSalaryPublic = val),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),

              // Footer Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submitJob(status: 'Draft'),
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save as Draft'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitJob(status: 'Active'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                        label: Text(
                          _isSubmitting ? 'Publishing...' : 'Publish Job Opening',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
