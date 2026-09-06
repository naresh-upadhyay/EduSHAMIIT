import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';

class BulkOperationsDialog extends ConsumerStatefulWidget {
  const BulkOperationsDialog({super.key});

  @override
  ConsumerState<BulkOperationsDialog> createState() => _BulkOperationsDialogState();
}

class _BulkOperationsDialogState extends ConsumerState<BulkOperationsDialog> {
  String _selectedAction = 'ARCHIVE';
  String _newCategory = 'General';
  String _newRack = 'Rack A';
  String _newShelf = 'Shelf 1';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookProvider);
    final notifier = ref.read(bookProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = state.selectedBookIds.length;

    final categories = state.filterOptions.categories;

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
                  const Icon(Icons.checklist_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  Text('Bulk Actions ($count Selected Books)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                  const Text('Select Operation to Perform:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),

                  _buildActionRadio('ARCHIVE', 'Archive Selected Books', Icons.archive_outlined, const Color(0xFFEF4444)),
                  _buildActionRadio('RESTORE', 'Restore Selected Books', Icons.unarchive_outlined, const Color(0xFF10B981)),
                  _buildActionRadio('CHANGE_CATEGORY', 'Update Category in Bulk', Icons.category_outlined, const Color(0xFF6366F1)),
                  _buildActionRadio('CHANGE_LOCATION', 'Relocate Physical Rack / Shelf', Icons.location_on_outlined, const Color(0xFFF59E0B)),

                  if (_selectedAction == 'CHANGE_CATEGORY') ...[
                    const SizedBox(height: 12),
                    const Text('New Category (Lookup):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: categories.contains(_newCategory) ? _newCategory : categories.first,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _newCategory = v);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],

                  if (_selectedAction == 'CHANGE_LOCATION') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => _newRack = v,
                            decoration: InputDecoration(
                              labelText: 'New Rack',
                              hintText: 'Rack A',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => _newShelf = v,
                            decoration: InputDecoration(
                              labelText: 'New Shelf',
                              hintText: 'Shelf 1',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                    onPressed: () async {
                      final success = await notifier.performBulkAction(
                        _selectedAction,
                        categoryName: _selectedAction == 'CHANGE_CATEGORY' ? _newCategory : null,
                        rack: _selectedAction == 'CHANGE_LOCATION' ? _newRack : null,
                        shelf: _selectedAction == 'CHANGE_LOCATION' ? _newShelf : null,
                      );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Execute Bulk Action'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRadio(String value, String title, IconData icon, Color color) {
    final isSelected = _selectedAction == value;
    return InkWell(
      onTap: () => setState(() => _selectedAction = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color.withOpacity(0.4) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? color : const Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500))),
            Radio<String>(
              value: value,
              groupValue: _selectedAction,
              activeColor: color,
              onChanged: (v) => setState(() => _selectedAction = v!),
            ),
          ],
        ),
      ),
    );
  }
}
