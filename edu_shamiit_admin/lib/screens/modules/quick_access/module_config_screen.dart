import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'quick_access_widgets.dart';

class ModuleConfigScreen extends StatefulWidget {
  const ModuleConfigScreen({super.key});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  Future<void> _fetchModules() async {
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load modules: $e')),
      );
    }
  }

  void _showConstraintWarningDialog(String message) {
    String schoolsText = '';
    if (message.contains('active for:')) {
      final parts = message.split('active for:');
      if (parts.length > 1) {
        final schoolParts = parts[1].split('. Please');
        schoolsText = schoolParts[0].trim();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: theme.scaffoldBackgroundColor,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_outlined,
                    color: Color(0xFFEF4444),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Deactivation Blocked',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This module cannot be deactivated or deleted because it is currently active for one or more institutions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (schoolsText.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACTIVE INSTITUTIONS:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: schoolsText.split(',').map((school) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                color: Color(0xFFEF4444),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                school.trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Dismiss',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/admin/modules');
                        },
                        child: const Text(
                          'Manage Toggles',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveModule(String? id, Map<String, dynamic> data) async {
    try {
      if (id == null) {
        await ApiService().post('/admin/schools/modules/all', data);
      } else {
        await ApiService().put('/admin/schools/modules/all/$id', data);
      }
      _fetchModules();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module saved successfully')),
      );
    } catch (e) {
      _fetchModules();
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save module: $e')),
        );
      }
    }
  }

  Future<void> _deleteModule(String id) async {
    try {
      await ApiService().delete('/admin/schools/modules/all/$id');
      _fetchModules();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module deleted successfully')),
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete module: $e')),
        );
      }
    }
  }

  void _showEditDialog([dynamic module]) {
    final isNew = module == null;
    final idController = TextEditingController(text: isNew ? '' : module['id']);
    final nameController = TextEditingController(text: isNew ? '' : module['name']);
    final descController = TextEditingController(text: isNew ? '' : module['description'] ?? '');
    final iconController = TextEditingController(text: isNew ? 'extension' : module['icon'] ?? 'extension');
    
    List<dynamic> screensList = isNew ? [] : (module['screens'] as List<dynamic>? ?? []);
    List<dynamic> endpointsList = isNew ? [] : (module['endpoints'] as List<dynamic>? ?? []);
    final screensController = TextEditingController(text: screensList.join(', '));
    final endpointsController = TextEditingController(text: endpointsList.join(', '));

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
            isNew ? 'Create Master Module' : 'Edit Master Module',
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    enabled: isNew,
                    decoration: const InputDecoration(
                      labelText: 'Module ID / Key',
                      hintText: 'e.g. academic_tracker',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Module Name',
                      hintText: 'e.g. Academic Tracker',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief summary of features',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Material Icon Name',
                      hintText: 'e.g. assessment, school, local_library',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: screensController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Controlled Screens (comma separated paths)',
                      hintText: '/student/exams, /teacher/exams',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpointsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Controlled Endpoints (comma separated paths)',
                      hintText: '/api/exams, /api/exam-questions',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final id = idController.text.trim();
                final name = nameController.text.trim();
                if (id.isEmpty || name.isEmpty) return;

                final screens = screensController.text.split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final endpoints = endpointsController.text.split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final payload = {
                  'id': id,
                  'name': name,
                  'description': descController.text.trim(),
                  'icon': iconController.text.trim(),
                  'screens': screens,
                  'endpoints': endpoints,
                  'is_enabled': isNew ? true : (module['is_enabled'] ?? true)
                };

                Navigator.pop(context);
                _saveModule(isNew ? null : id, payload);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconData(String? name) {
    if (name == null || name.isEmpty) return Icons.extension;
    switch (name) {
      case 'payment':
        return Icons.payment;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'local_library':
        return Icons.local_library;
      case 'hotel':
        return Icons.hotel;
      case 'assignment':
        return Icons.assignment;
      case 'video_call':
        return Icons.video_call;
      case 'chat':
        return Icons.chat;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'badge':
        return Icons.badge;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'sms':
        return Icons.sms;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return QuickAccessScaffold(
      title: 'Module Config Console',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Master Feature Modules Registry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Module'),
              onPressed: () => _showEditDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (_modules.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No master modules registered.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ..._modules.map((module) {
            final screens = module['screens'] as List<dynamic>? ?? [];
            final endpoints = module['endpoints'] as List<dynamic>? ?? [];
            final isEnabled = module['is_enabled'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIconData(module['icon']),
                          color: const Color(0xFF4F46E5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              module['name'] ?? 'Unnamed Module',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Key: ${module['id']}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        activeColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          _saveModule(module['id'], {'is_enabled': val});
                        },
                      ),
                    ],
                  ),
                  if (module['description'] != null && module['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      module['description'],
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (screens.isNotEmpty) ...[
                    const Text('Controlled Screens:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: screens.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.toString(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (endpoints.isNotEmpty) ...[
                    const Text('Controlled Endpoints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: endpoints.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.toString(),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontFamily: 'monospace'),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
                        label: const Text('Edit Configuration', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12)),
                        onPressed: () => _showEditDialog(module),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text('Delete Module', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: Text('Are you sure you want to delete module "${module['name']}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteModule(module['id']);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
