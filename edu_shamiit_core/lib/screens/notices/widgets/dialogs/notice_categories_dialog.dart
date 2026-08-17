import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notice_provider.dart';

class NoticeCategoriesDialog extends ConsumerStatefulWidget {
  const NoticeCategoriesDialog({super.key});

  @override
  ConsumerState<NoticeCategoriesDialog> createState() => _NoticeCategoriesDialogState();
}

class _NoticeCategoriesDialogState extends ConsumerState<NoticeCategoriesDialog> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String _selectedColor = '#3B82F6';
  bool _isSaving = false;

  final List<String> _colors = [
    '#3B82F6', // Blue
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EF4444', // Red
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#14B8A6', // Teal
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveNewCategory() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toLowerCase().replaceAll(' ', '_');
    if (name.isEmpty || code.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final api = ref.read(noticeApiServiceProvider);
      await api.saveCategory({
        'name': name,
        'code': code,
        'color': _selectedColor,
        'icon': 'notifications',
        'is_active': true,
        'sort_order': 10,
      });
      await ref.read(noticeProvider.notifier).fetchCategories();
      _nameController.clear();
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.category_rounded, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  Text(
                    'Manage Notice Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Add New Category Form
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add New Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          onChanged: (val) {
                            if (_codeController.text.isEmpty || _codeController.text == val.toLowerCase().replaceAll(' ', '_')) {
                              _codeController.text = val.toLowerCase().replaceAll(' ', '_');
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Category Name',
                            hintText: 'e.g. Sports',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Code',
                            hintText: 'e.g. sports',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Color Picker Row + Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: _colors.map((hex) {
                          final isSelected = _selectedColor == hex;
                          final color = Color(int.parse('FF${hex.replaceAll("#", "")}', radix: 16));
                          return InkWell(
                            onTap: () => setState(() => _selectedColor = hex),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveNewCategory,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Existing Categories List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final cat = state.categories[idx];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cat.colorValue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.circle, size: 12, color: cat.colorValue),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text('Code: ${cat.code}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(cat.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, color: cat.isActive ? Colors.green : Colors.grey)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
