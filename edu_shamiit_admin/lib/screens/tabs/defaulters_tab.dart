import 'package:flutter/material.dart';

class DefaultersTab extends StatelessWidget {
  const DefaultersTab({super.key});

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
            'Fee Defaulters Ledger',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Take immediate action to notify or contact parents of students with pending dues.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),

          // Core List
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
                  'Pending Dues List',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 20),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDefaulterItem(context,
                        name: 'Ananya Roy',
                        className: 'Class 10A',
                        amount: '₹57,000',
                        phone: '+91 98765 43210',
                        deadline: 'Expired (15 Days)'),
                    _buildDefaulterItem(context,
                        name: 'Aarav Mehta',
                        className: 'Class 11B',
                        amount: '₹45,000',
                        phone: '+91 99887 76655',
                        deadline: 'Expired (10 Days)'),
                    _buildDefaulterItem(context,
                        name: 'Tanisha Gupta',
                        className: 'Class 12A',
                        amount: '₹62,000',
                        phone: '+91 88776 65544',
                        deadline: 'Expired (5 Days)'),
                    _buildDefaulterItem(context,
                        name: 'Kabir Verma',
                        className: 'Class 9C',
                        amount: '₹38,000',
                        phone: '+91 77665 54433',
                        deadline: 'Due in 2 Days'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaulterItem(
    BuildContext context, {
    required String name,
    required String className,
    required String amount,
    required String phone,
    required String deadline,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUrgent = deadline.contains('Expired');

    final itemBg = isUrgent
        ? (isDark ? const Color(0xFF2D1616) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF0F1222) : const Color(0xFFF8FAFC));

    final itemBorderColor = isUrgent
        ? Colors.red.withValues(alpha: 0.3)
        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: itemBorderColor),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 550;

        final infoRow = Row(
          children: [
            CircleAvatar(
              backgroundColor: isUrgent
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              child: Icon(
                Icons.warning_amber_rounded,
                color: isUrgent ? Colors.red : Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$className  •  $phone',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionRow = Row(
          mainAxisAlignment: isWide ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  deadline,
                  style: TextStyle(
                    color: isUrgent ? Colors.red : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'Notice notification pushed to $name\'s parent.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isUrgent ? Colors.red : const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('Send Alert', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: infoRow),
              actionRow,
            ],
          );
        } else {
          return Column(
            children: [
              infoRow,
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              actionRow,
            ],
          );
        }
      }),
    );
  }
}
