import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherSalary extends StatefulWidget {
  const TeacherSalary({super.key});

  @override
  State<TeacherSalary> createState() => _TeacherSalaryState();
}

class _TeacherSalaryState extends State<TeacherSalary> {
  final TeacherApiService _apiService = TeacherApiService();
  
  List<SalarySlip> _salarySlips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSalarySlips();
  }

  Future<void> _loadSalarySlips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final slips = await _apiService.getSalarySlips();
      setState(() {
        _salarySlips = slips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
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
                  'Salary Slips',
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

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
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
                      onPressed: _loadSalarySlips,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Salary slips list
          if (!_isLoading && _error == null)
            Expanded(
              child: _salarySlips.isEmpty
                  ? const Center(child: Text('No salary slips found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _salarySlips.length,
                      itemBuilder: (context, index) {
                        return _buildSalarySlipCard(_salarySlips[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalarySlipCard(SalarySlip slip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Month/Year icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${slip.month} ${slip.year}',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Slip ID: ${slip.id.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Amount
              Text(
                '₹${slip.netSalary.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Breakdown
          _buildBreakdownRow('Basic Salary', '₹${slip.basicSalary.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildBreakdownRow('Allowances', '₹${slip.allowances.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildBreakdownRow('Deductions', '-₹${slip.deductions.toStringAsFixed(0)}', isNegative: true),
          const Divider(height: 24),
          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _viewDetails(slip),
                  icon: const Icon(Icons.visibility, size: 14),
                  label: const Text(
                    'View Details',
                    style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _downloadSlip(slip),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isNegative ? Colors.red : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  void _viewDetails(SalarySlip slip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Salary Details - ${slip.month} ${slip.year}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Earnings:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Basic Salary', '₹${slip.basicSalary.toStringAsFixed(0)}'),
              _buildDetailRow('Allowances', '₹${slip.allowances.toStringAsFixed(0)}'),
              const SizedBox(height: 12),
              const Text('Deductions:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Deductions', '₹${slip.deductions.toStringAsFixed(0)}'),
              const Divider(),
              _buildDetailRow('Net Salary', '₹${slip.netSalary.toStringAsFixed(0)}', isBold: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _downloadSlip(SalarySlip slip) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📄 Downloading salary slip for ${slip.month} ${slip.year}...')),
    );
  }
}