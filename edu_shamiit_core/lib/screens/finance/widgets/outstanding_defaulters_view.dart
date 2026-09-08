import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_provider.dart';

class OutstandingDefaultersView extends ConsumerStatefulWidget {
  final Function(String studentId)? onSelectStudent;
  final VoidCallback? onCollectPayment;

  const OutstandingDefaultersView({
    super.key,
    this.onSelectStudent,
    this.onCollectPayment,
  });

  @override
  ConsumerState<OutstandingDefaultersView> createState() => _OutstandingDefaultersViewState();
}

class _OutstandingDefaultersViewState extends ConsumerState<OutstandingDefaultersView> {
  String _selectedBucket = 'ALL';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeProvider);
    final notifier = ref.read(financeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaulters = state.ledgerItems.where((item) => item.amountBalance > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aging Buckets Filter Cards Row
          Row(
            children: [
              _buildBucketChip('ALL', 'All Overdue Dues', isDark),
              const SizedBox(width: 12),
              _buildBucketChip('0-30', '0 - 30 Days', isDark),
              const SizedBox(width: 12),
              _buildBucketChip('31-60', '31 - 60 Days', isDark),
              const SizedBox(width: 12),
              _buildBucketChip('61-90', '61 - 90 Days', isDark),
              const SizedBox(width: 12),
              _buildBucketChip('90+', '90+ Days Overdue', isDark, isDanger: true),
            ],
          ),
          const SizedBox(height: 24),

          // Defaulters List Container
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Outstanding Dues & Defaulters Registry (${defaulters.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          final ids = defaulters.map((e) => e.studentId).toSet().toList();
                          notifier.sendReminders(ids);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bulk payment reminders sent to ${ids.length} defaulters.')),
                          );
                        },
                        icon: const Icon(Icons.notifications_active_rounded, size: 16),
                        label: const Text('Send Bulk Reminders'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: defaulters.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = defaulters[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                      ),
                      title: Text(
                        item.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Class ${item.classSection} • Adm #${item.admissionNo} • Head: ${item.feeHead}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${item.amountBalance.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFEF4444)),
                              ),
                              Text(
                                'Due: ${item.dueDate}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: () => widget.onSelectStudent?.call(item.studentId),
                            child: const Text('View Dues'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBucketChip(String id, String label, bool isDark, {bool isDanger = false}) {
    final isSelected = _selectedBucket == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedBucket = id),
      selectedColor: isDanger ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}
