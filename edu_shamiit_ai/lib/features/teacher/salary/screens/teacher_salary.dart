import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherSalary extends StatefulWidget {
  const TeacherSalary({super.key});

  @override
  State<TeacherSalary> createState() => _TeacherSalaryState();
}

class _TeacherSalaryState extends State<TeacherSalary> {
  final Map<String, dynamic> _salaryDetails = {
    'basicSalary': 65000,
    'allowances': {
      'HRA': 15000,
      'TA': 3000,
      'DA': 5000,
      'Special': 2000,
    },
    'deductions': {
      'PF': 7800,
      'TDS': 3200,
      'Professional Tax': 200,
    },
    'grossSalary': 90000,
    'netSalary': 78800,
  };

  String _selectedMonth = 'April 2026';
  final List<String> _months = [
    'April 2026',
    'March 2026',
    'February 2026',
    'January 2026',
    'December 2025',
  ];

  final List<Map<String, dynamic>> _salaryHistory = [
    {
      'month': 'April 2026',
      'netSalary': 78800,
      'status': 'credited',
      'date': DateTime.now().subtract(const Duration(days: 2)),
    },
    {
      'month': 'March 2026',
      'netSalary': 78800,
      'status': 'credited',
      'date': DateTime.now().subtract(const Duration(days: 32)),
    },
    {
      'month': 'February 2026',
      'netSalary': 76500,
      'status': 'credited',
      'date': DateTime.now().subtract(const Duration(days: 62)),
    },
    {
      'month': 'January 2026',
      'netSalary': 78800,
      'status': 'credited',
      'date': DateTime.now().subtract(const Duration(days: 93)),
    },
    {
      'month': 'December 2025',
      'netSalary': 78800,
      'status': 'credited',
      'date': DateTime.now().subtract(const Duration(days: 123)),
    },
  ];

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
                  'Salary & Payslip',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📄 Downloading payslip...')),
                    );
                  },
                ),
              ],
            ),
          ),

          // Month selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Month:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMonth,
                        isExpanded: true,
                        items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedMonth = value);
                          }
                        },
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Salary content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Net salary card
                  _buildNetSalaryCard(),
                  const SizedBox(height: 16),

                  // Earnings and deductions
                  Row(
                    children: [
                      Expanded(child: _buildSummaryCard('Earnings', _calculateTotalEarnings(), Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSummaryCard('Deductions', _calculateTotalDeductions(), Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Earnings breakdown
                  _buildBreakdownSection('Earnings', _salaryDetails['allowances'] as Map<String, dynamic>, Colors.green),
                  const SizedBox(height: 16),

                  // Deductions breakdown
                  _buildBreakdownSection('Deductions', _salaryDetails['deductions'] as Map<String, dynamic>, Colors.red),
                  const SizedBox(height: 16),

                  // Salary history
                  _buildSalaryHistory(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom action button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📄 Downloading payslip PDF...')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text(
                    'Download Payslip PDF',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalEarnings() {
    double total = _salaryDetails['basicSalary'] as double;
    final allowances = _salaryDetails['allowances'] as Map<String, dynamic>;
    for (var value in allowances.values) {
      total += value as double;
    }
    return total;
  }

  double _calculateTotalDeductions() {
    double total = 0;
    final deductions = _salaryDetails['deductions'] as Map<String, dynamic>;
    for (var value in deductions.values) {
      total += value as double;
    }
    return total;
  }

  Widget _buildNetSalaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Text(
            'Net Salary',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_salaryDetails['netSalary']}',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedMonth,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniStat('Basic', '₹${_salaryDetails['basicSalary']}'),
              const SizedBox(width: 24),
              _buildMiniStat('Gross', '₹${_salaryDetails['grossSalary']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(String title, Map<String, dynamic> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '₹${entry.value}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹${items.values.fold<double>(0, (sum, val) => sum + (val as double)).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Salary History',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          ..._salaryHistory.map((salary) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          salary['month'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(salary['date'] as DateTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${salary['netSalary']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Credited',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}