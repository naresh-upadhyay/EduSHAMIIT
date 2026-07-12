import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'quick_access_widgets.dart';

class ModuleToggleScreen extends StatefulWidget {
  const ModuleToggleScreen({super.key});

  @override
  State<ModuleToggleScreen> createState() => _ModuleToggleScreenState();
}

class _ModuleToggleScreenState extends State<ModuleToggleScreen> {
  List<dynamic> _schools = [];
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final schoolsRes = await ApiService().get('/admin/schools', useCache: false);
      final modulesRes = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (schoolsRes['success'] == true && modulesRes['success'] == true) {
        setState(() {
          _schools = schoolsRes['data']['schools'] as List<dynamic>? ?? [];
          
          final allModules = modulesRes['data'] as List<dynamic>? ?? [];
          _modules = allModules.where((m) => m['is_enabled'] == true).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load module configuration: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return QuickAccessScaffold(
      title: 'Module Management',
      children: [
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (_schools.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No schools registered in the system.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ..._schools.map((school) {
            final logoUrl = school['logo_url']?.toString() ?? '';
            final address = school['address']?.toString() ?? 'UP, India';
            final existingUsers = school['existing_users'] ?? 0;
            final maxStudents = school['max_students'] ?? 1000;
            final moduleToggles = school['module_toggles'] as Map<String, dynamic>? ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School Info Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))
                              ? Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => const Icon(
                                    Icons.school_outlined,
                                    color: Color(0xFF4F46E5),
                                    size: 22,
                                  ),
                                )
                              : const Icon(
                                  Icons.school_outlined,
                                  color: Color(0xFF4F46E5),
                                  size: 22,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              school['name'] ?? 'Institution Name',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$address • $existingUsers / $maxStudents users',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  // Grid of Toggles
                  if (_modules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No globally active modules configured in setup.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 8,
                        mainAxisExtent: 44,
                      ),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final mod = _modules[index];
                        final label = mod['name'] ?? 'Feature';
                        final key = mod['id'] ?? '';
                        // Default to false for any newly added modules
                        final value = moduleToggles[key] as bool? ?? false;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: value ? const Color(0xFF10B981) : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: value,
                              activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (newVal) async {
                                final updatedToggles = Map<String, dynamic>.from(moduleToggles);
                                updatedToggles[key] = newVal;

                                setState(() {
                                  final sIndex = _schools.indexWhere((s) => s['id'] == school['id']);
                                  if (sIndex != -1) {
                                    _schools[sIndex]['module_toggles'] = updatedToggles;
                                  }
                                });

                                try {
                                  await ApiService().put('/admin/schools/${school['id']}', {
                                    'module_toggles': updatedToggles,
                                  });
                                } catch (e) {
                                  _fetchData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
