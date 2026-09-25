import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class HireCandidateDialog extends StatefulWidget {
  final String candidateId;
  final String applicationId;
  final String candidateName;
  final String jobTitle;
  final String department;
  final String? initialJoiningDate;
  final VoidCallback onHired;

  const HireCandidateDialog({
    super.key,
    required this.candidateId,
    required this.applicationId,
    required this.candidateName,
    required this.jobTitle,
    required this.department,
    this.initialJoiningDate,
    required this.onHired,
  });

  @override
  State<HireCandidateDialog> createState() => _HireCandidateDialogState();
}

class _HireCandidateDialogState extends State<HireCandidateDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _employeeIdController;

  DateTime _joiningDate = DateTime.now();
  bool _overrideVacancy = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _designationController = TextEditingController(text: widget.jobTitle);
    _departmentController = TextEditingController(text: widget.department);
    final randNum = 1000 + Random().nextInt(9000);
    _employeeIdController = TextEditingController(text: 'EMP-$randNum');

    if (widget.initialJoiningDate != null && widget.initialJoiningDate!.isNotEmpty) {
      try {
        _joiningDate = DateTime.parse(widget.initialJoiningDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _designationController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _selectJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _submitHire() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'application_id': widget.applicationId,
        'joining_date': DateFormat('yyyy-MM-dd').format(_joiningDate),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'employee_id': _employeeIdController.text.trim(),
        'override_vacancy_limit': _overrideVacancy,
      };

      await _apiService.post(
        '/recruitment/candidates/${widget.candidateId}/hire',
        payload,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations! ${widget.candidateName} has been officially hired as ${_designationController.text.trim()}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onHired();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiring Error: $e'),
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
        width: 580,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirm Official Hiring',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          '${widget.candidateName} • ${widget.jobTitle}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
              const Divider(height: 28),

              // Notice Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action will update candidate stage to "Hired", increment filled vacancies on the job opening, create a system employee profile, initialize an onboarding record in the HR module, and dispatch a formal Appointment Welcome Email to the candidate.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Employee ID & Joining Date
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _employeeIdController,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Employee ID',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Employee ID required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InkWell(
                      onTap: _selectJoiningDate,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Official Joining Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_joiningDate),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Designation & Department
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _designationController,
                      decoration: const InputDecoration(
                        labelText: 'Final Designation',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Designation required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Department required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Override Checkbox
              CheckboxListTile(
                value: _overrideVacancy,
                onChanged: (val) => setState(() => _overrideVacancy = val ?? false),
                title: const Text('Override vacancy limit (Authorized HR override)', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 16),

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
                    onPressed: _isSubmitting ? null : _submitHire,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Processing Hire...' : 'Confirm Hire & Onboard',
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
