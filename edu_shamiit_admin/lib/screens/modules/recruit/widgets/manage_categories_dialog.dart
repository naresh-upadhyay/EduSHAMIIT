import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class ManageCategoriesDialog extends StatefulWidget {
  final VoidCallback onCategoriesChanged;

  const ManageCategoriesDialog({super.key, required this.onCategoriesChanged});

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _categories = [];
  String? _errorMessage;

  // Form State
  bool _isCreating = false;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedIcon = 'policy';
  String _selectedColor = '#4F46E5';

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'policy', 'icon': Icons.policy_rounded, 'label': 'Policy'},
    {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Academic'},
    {'name': 'security', 'icon': Icons.security_rounded, 'label': 'Security'},
    {'name': 'health_and_safety', 'icon': Icons.health_and_safety_rounded, 'label': 'Safety'},
    {'name': 'event_available', 'icon': Icons.event_available_rounded, 'label': 'Leave'},
    {'name': 'payments', 'icon': Icons.payments_rounded, 'label': 'Finance'},
    {'name': 'admin_panel_settings', 'icon': Icons.admin_panel_settings_rounded, 'label': 'Admin'},
    {'name': 'folder_shared', 'icon': Icons.folder_shared_rounded, 'label': 'General'},
  ];

  final List<String> _colorOptions = [
    '#4F46E5', // Indigo
    '#0284C7', // Sky
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#14B8A6', // Teal
    '#8B5CF6', // Purple
    '#EC4899', // Pink
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/hr/categories', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name is required')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final res = await _api.post('/hr/categories', {
        'name': _nameController.text.trim(),
        'code': _codeController.text.trim().isNotEmpty
            ? _codeController.text.trim().toUpperCase()
            : _nameController.text.trim().replaceAll(' ', '_').toUpperCase(),
        'description': _descController.text.trim(),
        'icon': _selectedIcon,
        'color_hex': _selectedColor,
      });

      if (res['success'] == true) {
        _nameController.clear();
        _codeController.clear();
        _descController.clear();
        widget.onCategoriesChanged();
        await _fetchCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category created successfully'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _deleteCategory(String id, String name, bool isSystem) async {
    if (isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System categories cannot be deleted.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete category "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.delete('/hr/categories/$id');
      if (res['success'] == true) {
        widget.onCategoriesChanged();
        await _fetchCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4F46E5);
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'health_and_safety':
        return Icons.health_and_safety_rounded;
      case 'event_available':
        return Icons.event_available_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_rounded;
      case 'policy':
      default:
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        height: 650,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.category_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Policy & Document Categories',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Configure institutional document taxonomy and color-coded categories.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories List
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Existing Categories (${_categories.length})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                              child: _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _errorMessage != null
                                      ? Center(child: Text('Error: $_errorMessage'))
                                      : _categories.isEmpty
                                          ? const Center(child: Text('No categories found.'))
                                  : ListView.separated(
                                      itemCount: _categories.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final cat = _categories[index];
                                        final color = _parseColor(cat['color_hex']);
                                        final isSystem = cat['is_system'] == true;
                                        final docCount = cat['document_count'] ?? 0;
                                        final polCount = cat['policy_count'] ?? 0;

                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(_getIconData(cat['icon']), color: color, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          cat['name'] ?? '',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        if (isSystem) ...[
                                                          const SizedBox(width: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue.withValues(alpha: 0.1),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text(
                                                              'SYSTEM',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.blue,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '$docCount documents · $polCount policies',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (!isSystem)
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                  onPressed: () => _deleteCategory(cat['id'], cat['name'], isSystem),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 24),
                  // Add New Category Form
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Category',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Category Name *',
                              hintText: 'e.g. Health & Safety',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              labelText: 'Category Code (Optional)',
                              hintText: 'e.g. HEALTH_SAFETY',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Brief summary of what documents belong here...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Color Accent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _colorOptions.map((hex) {
                              final isSelected = _selectedColor == hex;
                              final c = _parseColor(hex);
                              return GestureDetector(
                                onTap: () => setState(() => _selectedColor = hex),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text('Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _iconOptions.map((opt) {
                              final isSelected = _selectedIcon == opt['name'];
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(opt['icon'] as IconData, size: 16),
                                    const SizedBox(width: 4),
                                    Text(opt['label'] as String, style: const TextStyle(fontSize: 11)),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedIcon = opt['name'] as String);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isCreating ? null : _createCategory,
                              icon: _isCreating
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.add_rounded, size: 18),
                              label: Text(_isCreating ? 'Creating...' : 'Add Category'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
