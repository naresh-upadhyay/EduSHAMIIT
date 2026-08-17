import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lookup_provider.dart';

class LookupFilterBar extends ConsumerStatefulWidget {
  const LookupFilterBar({super.key});

  @override
  ConsumerState<LookupFilterBar> createState() => _LookupFilterBarState();
}

class _LookupFilterBarState extends ConsumerState<LookupFilterBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(lookupProvider).searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Search Bar
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(lookupProvider.notifier).setSearchQuery(val);
              },
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search lookup keys...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(lookupProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
            ),
          ),

          // 2. Status Filter Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.statusFilter.isEmpty ? 'all' : state.statusFilter.toLowerCase(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                onChanged: (val) {
                  ref.read(lookupProvider.notifier).setStatusFilter(val == 'all' ? '' : val!.toUpperCase());
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Status: All')),
                  DropdownMenuItem(value: 'active', child: Text('Status: Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Status: Inactive')),
                ],
              ),
            ),
          ),

          // 3. Created By Filter Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.createdByFilter,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(lookupProvider.notifier).setCreatedByFilter(val);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Created By: All')),
                  DropdownMenuItem(value: 'my_keys', child: Text('Created By: My Keys')),
                  DropdownMenuItem(value: 'others', child: Text('Created By: Others')),
                  DropdownMenuItem(value: 'system', child: Text('Created By: System')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
