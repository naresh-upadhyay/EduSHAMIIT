import 'package:flutter/material.dart';

class SupportTab extends StatelessWidget {
  const SupportTab({super.key});

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
            'IT Support & System Control',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Resolve IT request tickets, network issues, and device health across campus wings.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 32),

          // Tickets List
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
                  'Pending Support Requests',
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
                    _buildTicketItem(context,
                        id: 'TKT-1082',
                        user: 'Neha Gupta (Teacher)',
                        subject: 'Classroom Smartboard Offline',
                        priority: 'High',
                        status: 'Pending'),
                    _buildTicketItem(context,
                        id: 'TKT-1081',
                        user: 'Admin Office',
                        subject: 'Receipt Printer Connection Issue',
                        priority: 'Medium',
                        status: 'In Progress'),
                    _buildTicketItem(context,
                        id: 'TKT-1080',
                        user: 'Ramesh Sen (Student)',
                        subject: 'LMS Password Reset Request',
                        priority: 'Low',
                        status: 'Pending'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketItem(
    BuildContext context, {
    required String id,
    required String user,
    required String subject,
    required String priority,
    required String status,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final priorityColor = priority == 'High'
        ? Colors.red
        : (priority == 'Medium' ? const Color(0xFFF59E0B) : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1222) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 550;

        final infoRow = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                priority[0],
                style: TextStyle(
                  color: priorityColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$id: $subject',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Requested by $user  •  Status: $status',
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
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ticket $id status updated to Resolved.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Resolve', style: TextStyle(fontSize: 11)),
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
