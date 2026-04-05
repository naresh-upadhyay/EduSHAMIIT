import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

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

  final List<Map<String, dynamic>> _leaveHistory = [
    {
      'type': 'Family Event',
      'start': DateTime(2025, 4, 12),
      'end': DateTime(2025, 4, 14),
      'reason': 'Attend my sister\'s wedding.',
      'status': 'PENDING',
      'icon': '✨',
    },
    {
      'type': 'Sick Leave',
      'start': DateTime(2025, 2, 8),
      'end': DateTime(2025, 2, 9),
      'reason': 'Suffering from viral fever.',
      'status': 'APPROVED',
      'icon': '🤒',
    },
    {
      'type': 'Urgent Work',
      'start': DateTime(2025, 1, 12),
      'end': DateTime(2025, 1, 12),
      'reason': 'Important family matter.',
      'status': 'APPROVED',
      'icon': '📦',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
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
                        color: StudentColors.primary.withOpacity(0.1),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatItem('15', 'Total Quota', StudentColors.primary),
                      _buildDivider(),
                      _buildStatItem('06', 'Used', StudentColors.success),
                      _buildDivider(),
                      _buildStatItem('01', 'Pending', StudentColors.warning),
                      _buildDivider(),
                      _buildStatItem('08', 'Balance', StudentColors.primary),
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
                          color: Colors.black.withOpacity(0.04),
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
                            value: _selectedLeaveType,
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
                              onPressed: _submitLeave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: StudentColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '✨ Apply for Leave',
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

                  // Upcoming Leave Cards
                  ..._leaveHistory.where((l) => l['status'] == 'PENDING').map((leave) => _buildLeaveCard(leave)),

                  const SizedBox(height: 16),

                  // Approved Leaves (also shown in upcoming tab)
                  ..._leaveHistory.where((l) => l['status'] == 'APPROVED').map((leave) => _buildLeaveCard(leave)),
                ] else ...[
                  // Past Leaves Tab
                  ..._buildPastLeaveCards(),
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

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final isPending = leave['status'] == 'PENDING';
    final isApproved = leave['status'] == 'APPROVED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                child: Center(child: Text(leave['icon'], style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leave['type'],
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${leave['start'].day}/${leave['start'].month}/${leave['start'].year} – ${leave['end'].day}/${leave['end'].month}/${leave['end'].year}',
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
                  leave['status'],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isPending ? StudentColors.warning : isApproved ? StudentColors.success : StudentColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (!isPending) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _editLeave(leave),
                    style: TextButton.styleFrom(
                      backgroundColor: StudentColors.border,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('✏️ Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => _cancelLeave(leave),
                    style: TextButton.styleFrom(
                      backgroundColor: StudentColors.errorBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('✕ Cancel', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: StudentColors.error)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPastLeaveCards() {
    return [
      _buildSimplePastCard('🤒', 'Medical Leave', 'Dec 15, 2024 • 1 day', 'COMPLETED'),
      _buildSimplePastCard('🏠', 'Casual Leave', 'Nov 20 – Nov 22, 2024 • 3 days', 'COMPLETED'),
      _buildSimplePastCard('📦', 'Urgent Work', 'Oct 5, 2024 • 1 day', 'REJECTED'),
    ];
  }

  Widget _buildSimplePastCard(String icon, String type, String date, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
        border: Border.all(color: StudentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.border,
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
                  type,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(fontSize: 10, color: StudentColors.text3),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: StudentColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: StudentColors.text3,
              ),
            ),
          ),
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

  void _submitLeave() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end dates')),
        );
        return;
      }

      // Add new leave to history
      setState(() {
        _leaveHistory.insert(0, {
          'type': _selectedLeaveType,
          'start': _startDate!,
          'end': _endDate!,
          'reason': _reasonController.text,
          'status': 'PENDING',
          'icon': _getLeaveIcon(_selectedLeaveType),
        });
      });

      // Show success dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('✨ Leave Applied!'),
          content: const Text('Your leave request has been submitted to your Class Teacher. You\'ll be notified once approved.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop(); // Go back to dashboard
              },
              child: const Text('Back to Home'),
            ),
          ],
        ),
      );

      _reasonController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
      });
    }
  }

  String _getLeaveIcon(String type) {
    switch (type) {
      case 'Sick Leave': return '🤒';
      case 'Casual Leave': return '🏠';
      case 'Urgent Work': return '📦';
      case 'Family Event': return '✨';
      default: return '📝';
    }
  }

  void _editLeave(Map<String, dynamic> leave) {
    setState(() {
      _selectedLeaveType = leave['type'];
      _startDate = leave['start'];
      _endDate = leave['end'];
      _reasonController.text = leave['reason'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit the form above and submit to update')),
    );
  }

  void _cancelLeave(Map<String, dynamic> leave) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave?'),
        content: const Text('Are you sure you want to cancel this leave request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                leave['status'] = 'CANCELLED';
              });
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: StudentColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}