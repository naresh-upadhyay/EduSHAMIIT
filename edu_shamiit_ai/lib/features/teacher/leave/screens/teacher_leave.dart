import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherLeave extends StatefulWidget {
  const TeacherLeave({super.key});

  @override
  State<TeacherLeave> createState() => _TeacherLeaveState();
}

class _TeacherLeaveState extends State<TeacherLeave> {
  String _selectedTab = 'Active';
  final List<String> _tabs = ['Active', 'Pending', 'Approved', 'Rejected'];

  final List<Map<String, dynamic>> _leaveApplications = [
    {
      'id': '1',
      'type': 'Sick Leave',
      'startDate': DateTime.now().subtract(const Duration(days: 2)),
      'endDate': DateTime.now().add(const Duration(days: 1)),
      'reason': 'Fever and headache',
      'status': 'pending',
      'appliedOn': DateTime.now().subtract(const Duration(days: 3)),
    },
    {
      'id': '2',
      'type': 'Casual Leave',
      'startDate': DateTime.now().add(const Duration(days: 5)),
      'endDate': DateTime.now().add(const Duration(days: 6)),
      'reason': 'Family function',
      'status': 'pending',
      'appliedOn': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'id': '3',
      'type': 'Medical Leave',
      'startDate': DateTime.now().subtract(const Duration(days: 10)),
      'endDate': DateTime.now().subtract(const Duration(days: 7)),
      'reason': 'Medical treatment',
      'status': 'approved',
      'appliedOn': DateTime.now().subtract(const Duration(days: 15)),
      'approvedBy': 'Principal',
    },
    {
      'id': '4',
      'type': 'Casual Leave',
      'startDate': DateTime.now().subtract(const Duration(days: 20)),
      'endDate': DateTime.now().subtract(const Duration(days: 20)),
      'reason': 'Personal work',
      'status': 'rejected',
      'appliedOn': DateTime.now().subtract(const Duration(days: 25)),
      'rejectedBy': 'Principal',
      'rejectionReason': 'Insufficient leave balance',
    },
  ];

  final Map<String, int> _leaveBalance = {
    'Sick Leave': 8,
    'Casual Leave': 12,
    'Medical Leave': 15,
    'Earned Leave': 20,
  };

  List<Map<String, dynamic>> get _filteredApplications {
    return _leaveApplications.where((l) => l['status'] == _selectedTab.toLowerCase()).toList();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getLeaveDuration(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    return '$days day${days > 1 ? 's' : ''}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'approved': return const Color(0xFF059669);
      case 'rejected': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
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
                  'Leave Application',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showApplyLeaveDialog(),
                ),
              ],
            ),
          ),

          // Leave balance summary
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leave Balance',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _leaveBalance.entries.map((entry) {
                      return _buildLeaveBalanceChip(entry.key, entry.value);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Applications list
          Expanded(
            child: _filteredApplications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('📅', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'No $_selectedTab applications',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredApplications.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveCard(_filteredApplications[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyLeaveDialog(),
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Apply Leave',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceChip(String type, int balance) {
    Color color;
    if (balance <= 2) {
      color = Colors.red;
    } else if (balance <= 5) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFF059669);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$balance',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final statusColor = _getStatusColor(leave['status'] as String);
    final duration = _getLeaveDuration(leave['startDate'] as DateTime, leave['endDate'] as DateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Text(
                  leave['type'] as String,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (leave['status'] as String).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date range
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${_formatDate(leave['startDate'] as DateTime)} - ${_formatDate(leave['endDate'] as DateTime)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Reason
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  leave['reason'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          // Status-specific info
          if (leave['status'] == 'approved' && leave['approvedBy'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Text(
                  'Approved by ${leave['approvedBy']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ],
          if (leave['status'] == 'rejected' && leave['rejectionReason'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Rejected: ${leave['rejectionReason']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Applied date
          Text(
            'Applied on ${_formatDate(leave['appliedOn'] as DateTime)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Leave'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _leaveBalance.keys
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        hintText: 'Select',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      readOnly: true,
                      onTap: () {
                        // Would show date picker
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        hintText: 'Select',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      readOnly: true,
                      onTap: () {
                        // Would show date picker
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Enter reason for leave...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Leave application submitted!')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}