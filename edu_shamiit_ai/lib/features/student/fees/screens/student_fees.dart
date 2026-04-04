import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentFees extends ConsumerStatefulWidget {
  const StudentFees({super.key});

  @override
  ConsumerState<StudentFees> createState() => _StudentFeesState();
}

class _StudentFeesState extends ConsumerState<StudentFees> {
  Map<String, dynamic>? _feesData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _feesData = {
        "total_outstanding": 12500.0,
        "total_paid": 37500.0,
        "pending_fees": [
          {
            "id": "uuid-fee-1",
            "fee_type": "Tuition Fee",
            "amount": 12500.0,
            "amount_paid": 0,
            "due_date": "2026-04-15",
            "status": "pending"
          }
        ],
        "recent_payments": [
          {
            "amount": 12500.0,
            "method": "UPI",
            "date": "2026-03-01",
            "transaction_id": "TXN123456"
          },
          {
            "amount": 12500.0,
            "method": "Net Banking",
            "date": "2026-02-01",
            "transaction_id": "TXN987654"
          },
          {
            "amount": 12500.0,
            "method": "Cash",
            "date": "2026-01-01",
            "transaction_id": "TXN456789"
          },
        ],
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final data = _feesData!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9),
      body: Column(
        children: [
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
                const Text(
                  'Fees',
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
                // Outstanding Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹ ${data['total_outstanding'].toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF065F46),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {},
                          child: const Text(
                            'PAY NOW',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Pending Fees
                const Text(
                  'Pending Fees',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...(data['pending_fees'] as List).map((fee) => _buildPendingCard(fee)),

                const SizedBox(height: 20),

                // Recent Payments
                const Text(
                  'Recent Payments',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...(data['recent_payments'] as List).map((payment) => _buildPaymentCard(payment)),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> fee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fee['fee_type'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Due: ${fee['due_date']}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${fee['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StudentColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    color: StudentColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.successBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('✅', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['method'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  payment['date'],
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹ ${payment['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: StudentColors.success,
                ),
              ),
              Text(
                payment['transaction_id'],
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11,
                  color: StudentColors.text3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}