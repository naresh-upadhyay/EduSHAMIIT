import 'package:flutter/material.dart';

class DefaultersTab extends StatelessWidget {
  const DefaultersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fee Defaulters Ledger',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Take immediate action to notify or contact parents of students with pending dues.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 32),

          // Core List
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
                  'Pending Dues List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDefaulterItem(context, name: 'Ananya Roy', className: 'Class 10A', amount: '₹57,000', phone: '+91 98765 43210', deadline: 'Expired (15 Days)'),
                    _buildDefaulterItem(context, name: 'Aarav Mehta', className: 'Class 11B', amount: '₹45,000', phone: '+91 99887 76655', deadline: 'Expired (10 Days)'),
                    _buildDefaulterItem(context, name: 'Tanisha Gupta', className: 'Class 12A', amount: '₹62,000', phone: '+91 88776 65544', deadline: 'Expired (5 Days)'),
                    _buildDefaulterItem(context, name: 'Kabir Verma', className: 'Class 9C', amount: '₹38,000', phone: '+91 77665 54433', deadline: 'Due in 2 Days'),
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
    final isUrgent = deadline.contains('Expired');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.03),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isUrgent ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: isUrgent ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$className  •  $phone',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amount,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deadline,
                    style: TextStyle(
                      color: isUrgent ? Colors.red : const Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notice notification pushed to $name\'s parent.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUrgent ? Colors.red : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Alert'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
