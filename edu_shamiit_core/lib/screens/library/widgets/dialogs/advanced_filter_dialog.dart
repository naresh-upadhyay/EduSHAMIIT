import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';

class AdvancedFilterDialog extends ConsumerStatefulWidget {
  const AdvancedFilterDialog({super.key});

  @override
  ConsumerState<AdvancedFilterDialog> createState() => _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends ConsumerState<AdvancedFilterDialog> {
  String? _language;
  String? _bookType;
  String? _rack;
  final TextEditingController _yearMinCtrl = TextEditingController();
  final TextEditingController _yearMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(bookProvider);
    _language = state.selectedLanguage;
    _bookType = state.selectedBookType;
    _rack = state.selectedRack;
    _yearMinCtrl.text = state.yearMin?.toString() ?? '';
    _yearMaxCtrl.text = state.yearMax?.toString() ?? '';
  }

  @override
  void dispose() {
    _yearMinCtrl.dispose();
    _yearMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final languages = ['All Languages', ...state.filterOptions.languages];
    final bookTypes = ['All Formats', ...state.filterOptions.bookTypes];
    final racks = ['All Racks', ...state.filterOptions.racks];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  const Text('Advanced Catalogue Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language
                  _buildDropdownRow(
                    label: 'Language',
                    value: _language ?? 'All Languages',
                    items: languages,
                    isDark: isDark,
                    onChanged: (v) => setState(() => _language = v == 'All Languages' ? null : v),
                  ),
                  const SizedBox(height: 12),

                  // Format
                  _buildDropdownRow(
                    label: 'Book Format / Type',
                    value: _bookType ?? 'All Formats',
                    items: bookTypes,
                    isDark: isDark,
                    onChanged: (v) => setState(() => _bookType = v == 'All Formats' ? null : v),
                  ),
                  const SizedBox(height: 12),

                  // Rack Location
                  _buildDropdownRow(
                    label: 'Physical Rack Location',
                    value: _rack ?? 'All Racks',
                    items: racks,
                    isDark: isDark,
                    onChanged: (v) => setState(() => _rack = v == 'All Racks' ? null : v),
                  ),
                  const SizedBox(height: 12),

                  // Year Range
                  const Text('Publication Year Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _yearMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Min Year (e.g. 2000)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('to', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _yearMaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Max Year (e.g. 2026)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      notifier.clearFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset All'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      notifier.setAdvancedFilters(
                        language: _language,
                        bookType: _bookType,
                        rack: _rack,
                        yearMin: int.tryParse(_yearMinCtrl.text.trim()),
                        yearMax: int.tryParse(_yearMaxCtrl.text.trim()),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              selectedItemBuilder: (context) {
                return items.map((e) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_formatLabel(e), maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }).toList();
              },
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(_formatLabel(e), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatLabel(String key) {
    if (key.contains('_') && key == key.toUpperCase()) {
      return key
          .split('_')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .join(' ');
    }
    return key;
  }
}
