import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_provider.dart';

class FeeStructuresView extends ConsumerWidget {
  final VoidCallback onCreateStructure;

  const FeeStructuresView({
    super.key,
    required this.onCreateStructure,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final structures = state.feeStructures;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fee Structure Catalog',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Define tuition, transport, exam, library and hostel fee packages per academic year.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onCreateStructure,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Fee Structure'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (structures.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Text(
                  'No fee structures configured yet.',
                  style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                ),
              ),
            )
          else
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 500,
                mainAxisExtent: 320,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: structures.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final s = structures[index];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              s.academicYear,
                              style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Applicable to: ${s.className}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const Divider(height: 24),

                      Expanded(
                        child: ListView.builder(
                          itemCount: s.items.length,
                          itemBuilder: (ctx, i) {
                            final item = s.items[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item['fee_head'] ?? '', style: const TextStyle(fontSize: 13)),
                                  Text('₹${item['amount']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Package Demand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            '₹${s.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF6366F1), fontFamily: 'Outfit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
