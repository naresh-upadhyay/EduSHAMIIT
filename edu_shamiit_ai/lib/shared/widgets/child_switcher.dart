import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';

/// Child switcher dropdown for parents with multiple children.
/// Placed in the app bar of parent screens.
class ChildSwitcher extends ConsumerWidget {
  const ChildSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenProvider);
    final selectedChildId = ref.watch(selectedChildProvider);

    return childrenAsync.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (children) {
        if (children.length <= 1) {
          // Single child — just show name
          if (children.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: ParentColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('👶', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  children.first['full_name'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ParentColors.text,
                  ),
                ),
              ],
            ),
          );
        }

        // Multiple children — show dropdown
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: ParentColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedChildId ?? children.first['student_id'],
              isDense: true,
              icon: const Icon(Icons.expand_more,
                  size: 18, color: ParentColors.primary),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ParentColors.primaryDeep,
              ),
              items: children.map<DropdownMenuItem<String>>((child) {
                return DropdownMenuItem<String>(
                  value: child['student_id'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👶', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('${child['full_name']} (${child['class']})'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(selectedChildProvider.notifier).state = value;
                }
              },
            ),
          ),
        );
      },
    );
  }
}
