import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';

class StudentFees extends ConsumerStatefulWidget {
  const StudentFees({super.key});

  @override
  ConsumerState<StudentFees> createState() => _StudentFeesState();
}

class _StudentFeesState extends ConsumerState<StudentFees> {
  final StudentApiService _apiService = StudentApiService();
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['Pending', 'Paid', 'All', 'Receipts'];
  List<FeeRecord> _feeRecords = [];
  double _totalOutstanding = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Map filter to API status
      final statusMap = {
        'Pending': 'pending',
        'Paid': 'paid',
        'All': null,
        'Receipts': 'paid',
      };
      
      final status = statusMap[_selectedFilter];
      final records = await _apiService.getFeeRecords(status: status);
      
      // Calculate total outstanding
      final totalOutstanding = records
          .where((f) => f.status == 'pending' || f.status == 'partial')
          .fold<double>(0, (sum, f) => sum + f.dueAmount);
      
      setState(() {
        _feeRecords = records;
        _totalOutstanding = totalOutstanding;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<FeeRecord> get _filteredFees {
    switch (_selectedFilter) {
      case 'Pending':
        return _feeRecords.where((f) => f.status == 'pending').toList();
      case 'Paid':
      case 'Receipts':
        return _feeRecords.where((f) => f.status == 'paid').toList();
      case 'All':
      default:
        return _feeRecords;
    }
  }

  String _getFeeIcon(String month) {
    if (month.toLowerCase().contains('transport') || month.toLowerCase().contains('bus')) {
      return '🚌';
    } else if (month.toLowerCase().contains('lab')) {
      return '🔬';
    } else if (month.toLowerCase().contains('library')) {
      return '📚';
    }
    return '📋';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return StudentColors.error;
      case 'partial':
        return StudentColors.warning;
      case 'paid':
        return StudentColors.success;
      default:
        return StudentColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0FDF9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: StudentColors.error),
              const SizedBox(height: 16),
              const Text(
                'Failed to load fees',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: StudentColors.text3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFees,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Fees & Payments',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Outstanding Card
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF065F46).withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outstanding Balance',
                        style: TextStyle(color: StudentColors.text3, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹ ${_totalOutstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_feeRecords.any((f) => f.status == 'pending'))
                        Row(
                          children: [
                            Text(
                              '⚠️ Due by ${_feeRecords.firstWhere((f) => f.status == 'pending').dueDate.day}/${_feeRecords.firstWhere((f) => f.status == 'pending').dueDate.month}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _showPaymentModal(context),
                          child: const Text(
                            '💳 Pay Now via UPI / Card / Net Banking',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Filter chips
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = filter == _selectedFilter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = filter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF059669) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Fees list
                if (_filteredFees.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No fee records found',
                        style: TextStyle(color: StudentColors.text3),
                      ),
                    ),
                  )
                else
                  ..._filteredFees.map((fee) => _buildFeeCard(fee)),

                const SizedBox(height: 12),

                // AI Tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFECFDF5), Color(0xFFF0FFF4)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🤖 AI REMINDER',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pay your pending fees before the due date to avoid late charges. EMI options available!',
                        style: TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.6),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/ai-chat'),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Text('🤖', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFeeCard(FeeRecord fee) {
    final statusColor = _getStatusColor(fee.status);
    final icon = _getFeeIcon(fee.month);
    final dueDateStr = fee.status == 'paid' && fee.paidDate != null
        ? 'Paid: ${fee.paidDate!.day}/${fee.paidDate!.month}'
        : 'Due: ${fee.dueDate.day}/${fee.dueDate.month}';
    final statusBgColor = fee.status == 'paid'
        ? const Color(0xFFECFDF5)
        : fee.status == 'partial'
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFFEF2F2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fee.month,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueDateStr,
                  style: const TextStyle(
                    color: StudentColors.text3,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${fee.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fee.status == 'paid'
                      ? 'PAID ✓'
                      : fee.status == 'partial'
                          ? 'PARTIAL'
                          : 'PENDING',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem('🏠', 'Home', false, () => context.go('/student/dashboard')),
          _buildNavItem('💳', 'Fees', true, null),
          _buildNavItem('📊', 'Results', false, () => context.go('/student/results')),
          _buildNavItem('📝', 'Homework', false, () => context.go('/student/homework')),
          _buildNavItem('👤', 'Profile', false, () => context.go('/student/profile')),
        ],
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💳 Select Payment Method',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethod('📱', 'UPI Payment', 'Google Pay, PhonePe, Paytm', () => _showPaymentSuccess(context)),
            _buildPaymentMethod('💳', 'Credit / Debit Card', 'Visa, Mastercard, RuPay', () {}),
            _buildPaymentMethod('🏦', 'Net Banking', 'All major banks supported', () {}),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: StudentColors.text3, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Text('›', style: TextStyle(fontSize: 20, color: Color(0xFFCBD5E1))),
          ],
        ),
      ),
    );
  }

  void _showPaymentSuccess(BuildContext context) {
    Navigator.pop(context); // Close payment modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 8),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '₹12,500 paid via UPI',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Transaction ID', 'TXN-2025-8847'),
                  const SizedBox(height: 6),
                  _buildReceiptRow('Date', 'Mar 27, 2025'),
                  const SizedBox(height: 6),
                  _buildReceiptRow('Status', '✓ Confirmed'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}