import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';

class StudentLeave extends ConsumerStatefulWidget {
  const StudentLeave({super.key});

  @override
  ConsumerState<StudentLeave> createState() => _StudentLeaveState();
}

class _StudentLeaveState extends ConsumerState<StudentLeave> {
  int _selectedTab = 0; // 0 = Upcoming, 1 = Past
  final _formKey = GlobalKey<FormState>();
  String _selectedLeaveType = 'Sick Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaveProvider.notifier).fetchLeaveApplications();
    });
  }

  String _getLeaveIcon(String type) {
    switch (type) {
      case 'Sick Leave': return '??';
      case 'Casual Leave': return '??';
      case 'Urgent Work': return '??';
      case 'Family Event': return '?';
      default: return '??';
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final applications = leaveState.applications;
    
    // Calculate stats
    final totalUsed = applications.length;
    final pendingCount = applications.where((a) => a.status == 'pending').length;
    final approvedCount = applications.where((a) => a.status == 'approved').length;
    final balance = 15 - approvedCount; // Assuming 15 days quota

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Leave Management',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Leave Dashboard
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: StudentColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatItem('15', 'Total Quota', StudentColors.primary),
                      _buildDivider(),
                      _buildStatItem(totalUsed.toString().padLeft(2, '0'), 'Used', StudentColors.success),
                      _buildDivider(),
                      _buildStatItem(pendingCount.toString().padLeft(2, '0'), 'Pending', StudentColors.warning),
                      _buildDivider(),
                      _buildStatItem(balance.toString().padLeft(2, '0'), 'Balance', StudentColors.primary),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Navigation
                Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'Upcoming Leaves',
                        0,
                        _selectedTab == 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTabButton(
                        'Past Leaves',
                        1,
                        _selectedTab == 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_selectedTab == 0) ...[
                  // Apply New Leave Section
                  const Text(
                    'Apply New Leave',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 15,
                        ),
                      ],
                      border: Border.all(color: StudentColors.primaryLight),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Leave Type
                          const Text(
                            'Leave Type',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.text3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedLeaveType,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: StudentColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: StudentColors.border),
                              ),
                            ),
                            items: ['Sick Leave', 'Casual Leave', 'Urgent Work', 'Family Event', 'Others']
                                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedLeaveType = value!),
                          ),

                          const SizedBox(height: 12),

                          // Date Range
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Start Date',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: StudentColors.text3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: StudentColors.surface,
                                          border: Border.all(color: StudentColors.border),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _startDate != null
                                              ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                                              : 'Select Date',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'End Date',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: StudentColors.text3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _selectDate(false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: StudentColors.surface,
                                          border: Border.all(color: StudentColors.border),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _endDate != null
                                              ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                              : 'Select Date',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Reason
                          const Text(
                            'Reason for Leave',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.text3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Describe the reason for your leave request...',
                              filled: true,
                              fillColor: StudentColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: StudentColors.border),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a reason';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // Upload Document
                          const Text(
                            'Supporting Document (Optional)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.text3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: StudentColors.border, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.attach_file, color: StudentColors.text3),
                                SizedBox(width: 8),
                                Text(
                                  'Tap to Upload Medical Note / Slip',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitLeave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: StudentColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      '? Apply for Leave',
                                      style: TextStyle(
                                        fontFamily: AppFonts.heading,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Show loading or leave cards
                  if (leaveState.isLoading && applications.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Pending Leave Cards
                    ...applications.where((l) => l.status == 'pending').map((leave) => _buildLeaveCardFromModel(leave)),

                    const SizedBox(height: 16),

                    // Approved Leaves
                    ...applications.where((l) => l.status == 'approved').map((leave) => _buildLeaveCardFromModel(leave)),
                  ],
                ] else ...[
                  // Past Leaves Tab
                  if (leaveState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    ...applications.where((l) => l.status == 'rejected' || l.status == 'cancelled').map((leave) => _buildLeaveCardFromModel(leave)),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: StudentColors.border,
    );
  }

  Widget _buildTabButton(String label, int index, bool isActive) {
    return ElevatedButton(
      onPressed: () => setState(() => _selectedTab = index),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? StudentColors.primary : StudentColors.primaryLight,
        foregroundColor: isActive ? Colors.white : StudentColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildLeaveCardFromModel(LeaveApplication leave) {
    final isPending = leave.status == 'pending';
    final isApproved = leave.status == 'approved';
    final icon = _getLeaveIcon(leave.leaveType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
        border: Border.all(
          color: isPending ? StudentColors.primaryLight : isApproved ? StudentColors.successBg : StudentColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPending ? StudentColors.primaryLight : isApproved ? StudentColors.successBg : StudentColors.errorBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave.leaveType,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leave.startDate} � ${leave.endDate}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: StudentColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? StudentColors.warningBg : isApproved ? StudentColors.successBg : StudentColors.errorBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isPending ? StudentColors.warning : isApproved ? StudentColors.success : StudentColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (isApproved) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Edit feature coming soon'.tr(ref))),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: StudentColors.border,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('?? Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cancel feature coming soon'.tr(ref))),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: StudentColors.errorBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('? Cancel', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudentColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitLeave() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select start and end dates'.tr(ref))),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      final success = await ref.read(leaveProvider.notifier).submitLeaveApplication(
        type: _selectedLeaveType,
        startDate: '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
        endDate: '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
        reason: _reasonController.text,
      );

      setState(() => _isSubmitting = false);

      if (success && mounted) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('? Leave Applied!'.tr(ref)),
            content: const Text('Your leave request has been submitted to your Class Teacher. You\'ll be notified once approved.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  safeGoBack(context, '/student/dashboard'); // Go back to dashboard
                },
                child: Text('Back to Home'.tr(ref)),
              ),
            ],
          ),
        );

        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit leave application. Please try again.'.tr(ref))),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
