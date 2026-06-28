import 'package:flutter/material.dart';

class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Financial Suite',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor tuition fees ledger, collections, processing channels and payments logs.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),

          // Core Accounts Panel
          Row(
            children: [
              _buildAccountTile(context, title: 'Tuition Fee Account', balance: '₹45,12,050', growth: '+12.4% vs last term'),
              const SizedBox(width: 20),
              _buildAccountTile(context, title: 'Transport Account', balance: '₹8,52,400', growth: '98% paid by students'),
              const SizedBox(width: 20),
              _buildAccountTile(context, title: 'Miscellaneous Receipts', balance: '₹1,90,500', growth: 'Includes library penalties'),
            ],
          ),
          const SizedBox(height: 32),

          // Ledger Table
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF13182C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Transactions Ledger',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.2),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                  children: [
                    _buildTableHeader(),
                    _buildTableRow('TXN-4902', 'Nidhi Sharma (Roll 14, 10A)', 'Tuition Fees', '₹28,500', 'Success'),
                    _buildTableRow('TXN-4901', 'Rahul Verma (Roll 08, 11A)', 'Transport Fees', '₹4,500', 'Success'),
                    _buildTableRow('TXN-4900', 'Priya Gupta (Roll 22, 10B)', 'Tuition Fees', '₹28,500', 'Pending'),
                    _buildTableRow('TXN-4899', 'Amit Patel (Roll 02, 12A)', 'Exam Registration', '₹1,200', 'Success'),
                    _buildTableRow('TXN-4898', 'Sneha Roy (Roll 31, 9B)', 'Library Overdue', '₹350', 'Success'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context, {required String title, required String balance, required String growth}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1B4B),
              Color(0xFF311042),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFFC084FC), fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              balance,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 8),
            Text(
              growth,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableHeader() {
    return const TableRow(
      children: [
        Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('TXN ID', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
        Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Student / Sender', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
        Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Category', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
        Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Amount', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
        Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Status', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
      ],
    );
  }

  TableRow _buildTableRow(String id, String sender, String category, String amount, String status) {
    final statusColor = status == 'Success' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(sender, style: const TextStyle(color: Color(0xFFCBD5E1)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(category, style: const TextStyle(color: Color(0xFF94A3B8)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
