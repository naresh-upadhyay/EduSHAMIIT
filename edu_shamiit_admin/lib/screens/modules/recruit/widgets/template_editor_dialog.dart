import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'package:edu_shamiit_admin/services/hr_template_presets.dart';
import 'institutional_document_renderer.dart';

class TemplateEditorDialog extends StatefulWidget {
  final VoidCallback onTemplatesChanged;
  final Map<String, dynamic>? initialTemplate;
  final String? initialTemplateId;

  const TemplateEditorDialog({
    super.key,
    required this.onTemplatesChanged,
    this.initialTemplate,
    this.initialTemplateId,
  });

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _templates = [];
  Map<String, dynamic>? _selectedTemplate;

  final _searchController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _contentController = TextEditingController();
  final _descController = TextEditingController();

  String _templateType = 'Warning Letter';
  String _selectedCategory = 'Employee Policies';
  String _selectedVarCategory = 'All';
  int _activeStudioTab = 0; // 0: Editor & Tags, 1: Live Letterhead Preview

  List<String> _standardTypes = [
    'Warning Letter',
    'Offer Letter',
    'Appointment Letter',
    'Experience Letter',
    'Relieving Letter',
    'NDA & Confidentiality',
    'Code of Conduct',
    'Salary Increment & Promotion',
    'Joining Checklist',
    'HR Forms',
    'Custom',
  ];

  List<String> _standardCategories = [
    'Administration',
    'Employee Policies',
    'Academic Policies',
    'IT & System Access',
    'Health & Safety',
    'Leave & Attendance',
    'Financial Policies',
    'Others',
  ];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadDynamicLookups();
    if (widget.initialTemplate != null) {
      _selectTemplate(widget.initialTemplate!);
    }
    _fetchTemplates();
  }

  Future<void> _loadDynamicLookups() async {
    try {
      final types = await HRLookupHelper.instance.getLookupLabels('HR_TEMPLATE_TYPE');
      final cats = await HRLookupHelper.instance.getLookupLabels('HR_TEMPLATE_CATEGORY');
      await HRTemplatePresets.fetchPresetsFromDb();

      if (mounted) {
        setState(() {
          if (types.isNotEmpty) {
            _standardTypes = types;
            if (!_standardTypes.contains(_templateType)) {
              _standardTypes.add(_templateType);
            }
          }
          if (cats.isNotEmpty) {
            _standardCategories = cats;
            if (!_standardCategories.contains(_selectedCategory)) {
              _standardCategories.add(_selectedCategory);
            }
          }
        });
      }
    } catch (_) {}
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadDynamicLookups();
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _searchController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _contentController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/hr/templates', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _templates = res['data'] ?? [];
          _isLoading = false;

          if (_templates.isNotEmpty) {
            if (widget.initialTemplateId != null) {
              final found = _templates.firstWhere(
                (t) => t['id']?.toString() == widget.initialTemplateId,
                orElse: () => null,
              );
              if (found != null) {
                _selectTemplate(found);
                return;
              }
            }
            if (widget.initialTemplate != null) {
              final found = _templates.firstWhere(
                (t) => t['id']?.toString() == widget.initialTemplate!['id']?.toString(),
                orElse: () => null,
              );
              if (found != null) {
                _selectTemplate(found);
                return;
              }
            }
            if (_selectedTemplate == null) {
              _selectTemplate(_templates.first);
            }
          } else {
            _createNewTemplate(type: 'Warning Letter');
          }
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _selectTemplate(Map<String, dynamic> t) {
    setState(() {
      _selectedTemplate = t;
      _codeController.text = t['template_code'] ?? '';
      _nameController.text = t['template_name'] ?? '';
      _descController.text = t['description'] ?? '';

      final type = t['template_type']?.toString() ?? 'Warning Letter';
      _templateType = _standardTypes.contains(type) ? type : (_standardTypes.firstWhere((st) => st.toLowerCase() == type.toLowerCase(), orElse: () => 'Custom'));

      final cat = t['category_name']?.toString() ?? 'Employee Policies';
      _selectedCategory = _standardCategories.contains(cat) ? cat : _standardCategories.first;

      _contentController.text = t['content_html'] ?? '';
    });
  }

  void _createNewTemplate({String? type}) {
    final targetType = type ?? _templateType;
    final preset = HRTemplatePresets.getPresetForType(targetType);
    final year = DateTime.now().year;
    final rand = DateTime.now().millisecond;

    setState(() {
      _selectedTemplate = null;
      _templateType = targetType;
      _selectedCategory = preset.category;
      _codeController.text = '${preset.code}-$year-$rand';
      _nameController.text = preset.name;
      _descController.text = preset.description;
      _contentController.text = preset.contentHtml.trim();
      _activeStudioTab = 0;
    });
  }

  void _loadPresetForCurrentType() {
    final preset = HRTemplatePresets.getPresetForType(_templateType);
    setState(() {
      _contentController.text = preset.contentHtml.trim();
      if (_descController.text.trim().isEmpty || _descController.text.startsWith('Reusable')) {
        _descController.text = preset.description;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Loaded standard $_templateType enterprise template!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onTypeChanged(String? newType) {
    if (newType == null || newType == _templateType) return;

    final isNewOrUnmodified = _selectedTemplate == null ||
        _contentController.text.trim().isEmpty ||
        _contentController.text.contains('This is to certify that') ||
        _contentController.text.contains('CONFIDENTIAL & OFFICIAL NOTIFICATION');

    setState(() {
      _templateType = newType;
      final preset = HRTemplatePresets.getPresetForType(newType);

      // If creating new template or user hasn't heavily customized, load preset automatically!
      if (_selectedTemplate == null || isNewOrUnmodified) {
        _contentController.text = preset.contentHtml.trim();
        _nameController.text = preset.name;
        _descController.text = preset.description;
        _selectedCategory = preset.category;
        final rand = DateTime.now().millisecond;
        _codeController.text = '${preset.code}-$rand';
      }
    });
  }

  void _insertVariable(String varName) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final insertion = '{{$varName}}';

    if (selection.start >= 0 && selection.end >= selection.start) {
      final newText = text.replaceRange(selection.start, selection.end, insertion);
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + insertion.length),
      );
    } else {
      _contentController.text += insertion;
    }

    HapticFeedback.selectionClick();
  }

  Future<void> _saveTemplate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Template Name'), backgroundColor: Colors.red),
      );
      return;
    }

    final code = _codeController.text.trim().isEmpty ? 'TMPL-${DateTime.now().millisecond}' : _codeController.text.trim();
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template content cannot be empty'), backgroundColor: Colors.red),
      );
      return;
    }

    // Extract all dynamic {{tags}} present in the content
    final reg = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');
    final matches = reg.allMatches(content);
    final variablesUsed = matches.map((m) => m.group(1)!).toSet().toList();

    setState(() => _isSaving = true);

    final payload = {
      'template_code': code,
      'template_name': name,
      'template_type': _templateType,
      'description': _descController.text.trim(),
      'category_name': _selectedCategory,
      'content_html': content,
      'variables': variablesUsed.isNotEmpty ? variablesUsed : ['employee_name', 'designation', 'institution_name'],
    };

    try {
      if (_selectedTemplate == null) {
        // Create new
        final res = await _api.post('/hr/templates', payload);
        if (res['success'] == true) {
          widget.onTemplatesChanged();
          await _fetchTemplates();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New template created successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception(res['message'] ?? 'Failed to create template');
        }
      } else {
        // Update existing
        final id = _selectedTemplate!['id'];
        final res = await _api.patch('/hr/templates/$id', payload);
        if (res['success'] == true) {
          widget.onTemplatesChanged();
          await _fetchTemplates();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template updated successfully!'), backgroundColor: Color(0xFF10B981)),
            );
          }
        } else {
          throw Exception(res['message'] ?? 'Failed to update template');
        }
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

  Future<void> _deleteTemplate() async {
    if (_selectedTemplate == null) return;
    final id = _selectedTemplate!['id'];
    final name = _selectedTemplate!['template_name'] ?? 'Template';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Template'),
        content: Text('Are you sure you want to deactivate "$name"? It will be hidden from new issuances.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.delete('/hr/templates/$id');
      if (res['success'] == true) {
        widget.onTemplatesChanged();
        _selectedTemplate = null;
        await _fetchTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template deactivated successfully.'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('warn')) return const Color(0xFFEF4444);
    if (t.contains('offer')) return const Color(0xFF3B82F6);
    if (t.contains('appoint')) return const Color(0xFF6366F1);
    if (t.contains('exp') || t.contains('cert')) return const Color(0xFF10B981);
    if (t.contains('reliev')) return const Color(0xFFF59E0B);
    if (t.contains('nda') || t.contains('confid')) return const Color(0xFF8B5CF6);
    if (t.contains('conduct')) return const Color(0xFF06B6D4);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.94).clamp(920.0, 1260.0);
    final dialogHeight = (size.height * 0.90).clamp(620.0, 840.0);

    final filteredTemplates = _templates.where((t) {
      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (t['template_name'] ?? '').toString().toLowerCase();
      final type = (t['template_type'] ?? '').toString().toLowerCase();
      final code = (t['template_code'] ?? '').toString().toLowerCase();
      return name.contains(q) || type.contains(q) || code.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Top Master Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HR Document & Letter Templates Studio',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Design and issue legally compliant institutional letters with real-world formatting & dynamic tags.',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _createNewTemplate(),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        label: const Text('Create New Template', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close Studio',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Body: 2-Column Studio
            Expanded(
              child: Row(
                children: [
                  // Left Pane: Templates Library List (30% width)
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
                      border: Border(
                        right: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search templates...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TEMPLATES (${filteredTemplates.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            InkWell(
                              onTap: () => _createNewTemplate(),
                              child: const Text('+ New', style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : filteredTemplates.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.folder_open_rounded, size: 36, color: Colors.grey),
                                          const SizedBox(height: 8),
                                          const Text('No templates found', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          const SizedBox(height: 10),
                                          TextButton(
                                            onPressed: () => _createNewTemplate(),
                                            child: const Text('Create from Preset', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: filteredTemplates.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (ctx, idx) {
                                        final item = filteredTemplates[idx];
                                        final isSelected = _selectedTemplate?['id'] == item['id'];
                                        final tType = item['template_type'] ?? 'Template';
                                        final typeColor = _getTypeColor(tType);

                                        return InkWell(
                                          onTap: () => _selectTemplate(item),
                                          borderRadius: BorderRadius.circular(10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? (isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF))
                                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                                width: isSelected ? 1.6 : 1.0,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: typeColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        item['template_name'] ?? 'Untitled Template',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                          color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: typeColor.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        tType,
                                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                                                      ),
                                                    ),
                                                    Text(
                                                      item['template_code'] ?? '',
                                                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),

                  // Right Pane: The Template Studio (70% width)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Metadata Controls Bar
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13182C) : Colors.white,
                            border: Border(
                              bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Template Name Field
                                  Expanded(
                                    flex: 5,
                                    child: TextField(
                                      controller: _nameController,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        labelText: 'Template Title / Name *',
                                        hintText: 'e.g. Formal Disciplinary & Performance Warning Notice',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Letter Type Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Letter Type *',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: AppSearchableDropdown<String>.fromMenuItems(
                                          value: _templateType,
                                          isExpanded: true,
                                          isDense: true,
                                          items: _standardTypes.map((type) {
                                            return DropdownMenuItem(
                                              value: type,
                                              child: Text(type, style: const TextStyle(fontSize: 12)),
                                            );
                                          }).toList(),
                                          onChanged: _onTypeChanged,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Code Field
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _codeController,
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                      decoration: InputDecoration(
                                        labelText: 'Code *',
                                        hintText: 'TMPL-WARN-01',
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Category Selector
                                  Row(
                                    children: [
                                      const Text('Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: AppSearchableDropdown<String>.fromMenuItems(
                                            value: _selectedCategory,
                                            isDense: true,
                                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                                            items: _standardCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                            onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Preset quick-loader button
                                  OutlinedButton.icon(
                                    onPressed: _loadPresetForCurrentType,
                                    icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF4F46E5)),
                                    label: Text('Load Standard $_templateType Preset', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      side: const BorderSide(color: Color(0xFF4F46E5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Studio Tab Switcher (Compose vs Live Letterhead Preview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            border: Border(
                              bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildStudioTab(0, 'Compose & Variables', Icons.edit_note_rounded, isDark),
                              const SizedBox(width: 8),
                              _buildStudioTab(1, 'Live Institutional Preview', Icons.visibility_rounded, isDark),
                            ],
                          ),
                        ),

                        // Studio Main Body
                        Expanded(
                          child: _activeStudioTab == 0
                              ? _buildComposeAndTagsView(isDark)
                              : _buildLiveLetterheadPreview(isDark),
                        ),

                        // Studio Footer Actions Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF13182C) : Colors.white,
                            border: Border(
                              top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_selectedTemplate != null)
                                TextButton.icon(
                                  onPressed: _isSaving ? null : _deleteTemplate,
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  label: const Text('Deactivate Template', style: TextStyle(color: Colors.red, fontSize: 12)),
                                )
                              else
                                const Text('New Template (Unsaved)', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _isSaving ? null : _saveTemplate,
                                    icon: _isSaving
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                                    label: Text(
                                      _isSaving ? 'Saving...' : (_selectedTemplate == null ? 'Save & Create Template' : 'Update Template'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildStudioTab(int index, String label, IconData icon, bool isDark) {
    final isSelected = _activeStudioTab == index;
    return InkWell(
      onTap: () => setState(() => _activeStudioTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeAndTagsView(bool isDark) {
    final categories = ['All', 'Employee', 'Job & Role', 'Dates & Terms', 'Disciplinary & Review', 'Organization'];
    final filteredVars = _selectedVarCategory == 'All'
        ? HRTemplatePresets.allVariables
        : HRTemplatePresets.allVariables.where((v) => v.category == _selectedVarCategory).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Variable Insertion Toolbar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Insert Variable:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: categories.map((cat) {
                            final isSel = _selectedVarCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: InkWell(
                                onTap: () => setState(() => _selectedVarCategory = cat),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF4F46E5) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 68),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: filteredVars.map((v) {
                        return ActionChip(
                          label: Text('{{${v.tag}}}', style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF4F46E5)),
                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                          tooltip: '${v.label} (e.g. ${v.sampleValue})',
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onPressed: () => _insertVariable(v.tag),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Template Editor Area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.6),
                  decoration: InputDecoration(
                    hintText: 'Enter template content with HTML formatting and dynamic variables like {{employee_name}}...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLetterheadPreview(bool isDark) {
    final raw = _contentController.text;
    final substituted = HRTemplatePresets.substituteVariables(raw, _templateType);
    final isWarning = _templateType.toLowerCase().contains('warn');
    final code = _codeController.text.trim().isEmpty ? 'TMPL-2026' : _codeController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.fromLTRB(36, 40, 36, 44),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Letterhead Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GREENFIELD INTERNATIONAL INSTITUTION',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'DIVISION OF HUMAN RESOURCES & TALENT MANAGEMENT',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), thickness: 1.5),
              const SizedBox(height: 14),

              // Ref & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ref: $code/2026', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const Text('Date: 24 September 2026', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 20),

              // Disciplinary Alert Badge if Warning Letter
              if (isWarning) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('FORMAL DISCIPLINARY & PERFORMANCE RECORD', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Title
              Center(
                child: Text(
                  (_nameController.text.trim().isEmpty ? _templateType : _nameController.text.trim()).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    decoration: TextDecoration.underline,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rendered Body with Rich Tables, Lists, and Typography
              InstitutionalDocumentRenderer(
                htmlContent: substituted,
                templateType: _templateType,
                isDark: isDark,
              ),
              const SizedBox(height: 40),

              // Signatures
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 140, height: 1, color: isDark ? Colors.white30 : Colors.black26),
                      const SizedBox(height: 6),
                      const Text('Authorized Signatory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const Text('Head of Administration & HR', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('INSTITUTION SEAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
