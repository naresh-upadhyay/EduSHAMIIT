import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/lookup_provider.dart';
import 'widgets/dialogs/create_edit_lookup_key_dialog.dart';
import 'widgets/lookup_detail_view.dart';
import 'widgets/lookup_filter_bar.dart';
import 'widgets/lookup_header_bar.dart';
import 'widgets/lookup_key_card.dart';
import 'widgets/lookup_tabs_bar.dart';

class LookupManagementScreen extends ConsumerStatefulWidget {
  const LookupManagementScreen({super.key});

  @override
  ConsumerState<LookupManagementScreen> createState() => _LookupManagementScreenState();
}

class _LookupManagementScreenState extends ConsumerState<LookupManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            const LookupHeaderBar(),

            // Main Content Area
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(context, state, isDark)
                  : _buildDesktopLayout(context, state, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // Desktop 2-Panel Layout
  Widget _buildDesktopLayout(BuildContext context, LookupState state, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final leftPanelWidth = screenWidth > 1300 ? 380.0 : (screenWidth > 1100 ? 340.0 : 310.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel (Keys List, Search, Filters, Tabs)
        SizedBox(
          width: leftPanelWidth,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              children: [
                // Tabs
                const LookupTabsBar(),

                // Filters & Search
                const LookupFilterBar(),

                const Divider(height: 1),

                // Keys List
                Expanded(
                  child: state.isKeysLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                      : state.keys.isEmpty
                          ? _buildEmptyKeysState(context, isDark)
                          : ListView.builder(
                              itemCount: state.keys.length,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemBuilder: (ctx, idx) {
                                final key = state.keys[idx];
                                final isSelected = state.selectedKey?.id == key.id;
                                return LookupKeyCard(
                                  lookupKey: key,
                                  isSelected: isSelected,
                                  onTap: () {
                                    ref.read(lookupProvider.notifier).selectKey(key.id);
                                  },
                                );
                              },
                            ),
                ),

                // Left Panel Pagination
                if (state.keysTotalRecords > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Page ${state.keysPage} of ${state.keysTotalPages > 0 ? state.keysTotalPages : 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: AppSearchableDropdown<int>.fromMenuItems(
                                  value: [10, 25, 50, 100].contains(state.keysPageSize) ? state.keysPageSize : 10,
                                  isDense: true,
                                  isExpanded: false,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  items: const [10, 25, 50, 100]
                                      .map((s) => DropdownMenuItem<int>(value: s, child: Text('$s')))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) ref.read(lookupProvider.notifier).setKeysPageSize(val);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: state.keysPage > 1
                                  ? () => ref.read(lookupProvider.notifier).setKeysPage(state.keysPage - 1)
                                  : null,
                            ),
                            Text(
                              '${state.keysPage}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: state.keysPage < state.keysTotalPages
                                  ? () => ref.read(lookupProvider.notifier).setKeysPage(state.keysPage + 1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Right Panel (Detail View)
        Expanded(
          child: state.selectedKey == null
              ? _buildNoSelectionPlaceholder(context, isDark)
              : state.isDetailLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : LookupDetailView(lookupKey: state.selectedKey!),
        ),
      ],
    );
  }

  // Mobile / Small Screen Layout
  Widget _buildMobileLayout(BuildContext context, LookupState state, bool isDark) {
    if (state.selectedKey != null) {
      return Column(
        children: [
          // Back bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    // Deselect key to go back to list
                    ref.read(lookupProvider.notifier).loadKeys(preserveSelection: false);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.selectedKey!.keyName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LookupDetailView(lookupKey: state.selectedKey!),
          ),
        ],
      );
    }

    return Column(
      children: [
        const LookupTabsBar(),
        const LookupFilterBar(),
        const Divider(height: 1),
        Expanded(
          child: state.isKeysLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              : state.keys.isEmpty
                  ? _buildEmptyKeysState(context, isDark)
                  : ListView.builder(
                      itemCount: state.keys.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (ctx, idx) {
                        final key = state.keys[idx];
                        return LookupKeyCard(
                          lookupKey: key,
                          isSelected: false,
                          onTap: () {
                            ref.read(lookupProvider.notifier).selectKey(key.id);
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyKeysState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              'No Lookup Keys Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing your search query or tab filters.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const CreateEditLookupKeyDialog(),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Create Lookup Key'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelectionPlaceholder(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.touch_app_rounded, size: 32, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a Lookup Key',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a lookup key from the left panel to view its values, manage options, and see cross-module usage statistics.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
