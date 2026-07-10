import 'package:flutter/material.dart';

class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Financial Suite',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor tuition fees ledger, collections, processing channels and payments logs.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),

          // Core Accounts Panel
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final children = [
              _buildAccountTile(context,
                  title: 'Tuition Fee Account',
                  balance: '₹45,12,050',
                  growth: '+12.4% vs last term'),
              if (!isWide) const SizedBox(height: 16) else const SizedBox(width: 20),
              _buildAccountTile(context,
                  title: 'Transport Account',
                  balance: '₹8,52,400',
                  growth: '98% paid by students'),
              if (!isWide) const SizedBox(height: 16) else const SizedBox(width: 20),
              _buildAccountTile(context,
                  title: 'Miscellaneous Receipts',
                  balance: '₹1,90,500',
                  growth: 'Includes library penalties'),
            ];

            if (isWide) {
              return Row(children: children);
            } else {
              return Column(children: children);
            }
          }),
          const SizedBox(height: 32),

          // Ledger Table
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Transactions Ledger',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
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
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  children: [
                    _buildTableHeader(context),
                    _buildTableRow(context, 'TXN-4902', 'Nidhi Sharma (Roll 14, 10A)',
                        'Tuition Fees', '₹28,500', 'Success'),
                    _buildTableRow(context, 'TXN-4901', 'Rahul Verma (Roll 08, 11A)',
                        'Transport Fees', '₹4,500', 'Success'),
                    _buildTableRow(context, 'TXN-4900', 'Priya Gupta (Roll 22, 10B)',
                        'Tuition Fees', '₹28,500', 'Pending'),
                    _buildTableRow(context, 'TXN-4899', 'Amit Patel (Roll 02, 12A)',
                        'Exam Registration', '₹1,200', 'Success'),
                    _buildTableRow(context, 'TXN-4898', 'Sneha Roy (Roll 31, 9B)',
                        'Library Overdue', '₹350', 'Success'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(BuildContext context,
      {required String title,
      required String balance,
      required String growth}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tileContent = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
                color: isDark ? const Color(0xFFC084FC) : const Color(0xFF4F46E5),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 12),
          Text(
            balance,
            style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 6),
          Text(
            growth,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 11,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );

    return Expanded(child: tileContent);
  }

  TableRow _buildTableHeader(BuildContext context) {
    final textStyle = TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF94A3B8)
          : const Color(0xFF64748B),
      fontWeight: FontWeight.bold,
      fontSize: 12,
      fontFamily: 'Outfit',
    );

    return TableRow(
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('TXN ID', style: textStyle)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Student / Sender', style: textStyle)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Category', style: textStyle)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Amount', style: textStyle)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Status', style: textStyle)),
      ],
    );
  }

  TableRow _buildTableRow(
      BuildContext context, String id, String sender, String category, String amount, String status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statusColor = status == 'Success' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusBg = statusColor.withValues(alpha: 0.1);

    final valueStyle = TextStyle(
      color: isDark ? Colors.white : const Color(0xFF0F172A),
      fontWeight: FontWeight.w500,
      fontSize: 12,
      fontFamily: 'Outfit',
    );

    return TableRow(
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(id, style: valueStyle)),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              sender,
              style: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            )),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              category,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontFamily: 'Outfit'),
            )),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              amount,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Outfit',
              ),
            )),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
