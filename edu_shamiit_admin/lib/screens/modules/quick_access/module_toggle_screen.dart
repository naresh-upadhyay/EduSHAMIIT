import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:go_router/go_router.dart';

class ModuleToggleScreen extends StatefulWidget {
  const ModuleToggleScreen({super.key});

  @override
  State<ModuleToggleScreen> createState() => _ModuleToggleScreenState();
}

class _ModuleToggleScreenState extends State<ModuleToggleScreen> {
  String _activeTab = 'All Modules'; // All Modules, Module Categories, Assign Modules, Module Requests
  List<dynamic> _modules = [];
  List<dynamic> _schools = [];
  bool _isLoading = true;

  // Search and Filters
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _selectedTypeFilter = 'All';

  // Pagination
  int _currentPage = 1;
  int _pageSize = 10;

  // Categories Pagination & Search
  int _categoriesCurrentPage = 1;
  int _categoriesPageSize = 10;
  String _categoriesSearchQuery = '';

  // Assign Modules Pagination
  int _assignCurrentPage = 1;
  int _assignPageSize = 10;

  // Module Requests Pagination
  int _requestsCurrentPage = 1;
  int _requestsPageSize = 10;

  // Sidebar selection
  Map<String, dynamic>? _selectedModule;
  Map<String, dynamic>? _selectedCategory;

  // Selected school assignments locally managed
  final Set<String> _assignedSchoolIds = {};
  String _schoolSearchQuery = '';

  // Tab 3: Assign Modules flow variables
  int _assignStep = 1; // 1: Select Institution, 2: Select Modules, 3: Review & Confirm
  String? _selectedSchoolId;
  final Set<String> _assignTabCheckedModuleIds = {};
  final Set<String> _assignTabOriginalModuleIds = {};
  String _assignModulesSearchQuery = '';
  String _assignModulesCategoryFilter = 'All';

  // Tab 4: Module Requests variables
  List<dynamic> _requests = [];
  Map<String, dynamic>? _selectedRequest;
  String _requestsSearchQuery = '';
  String _requestsSubTab = 'All Requests'; // All Requests, Pending, Approved, Rejected

  // Master categories list (derived or static fallback)
  final List<Map<String, dynamic>> _predefinedCategories = [
    {'name': 'Core', 'desc': 'Core infrastructure and identity management services.', 'status': 'Active'},
    {'name': 'Academics', 'desc': 'Track student coursework, examinations, timetables, and grading.', 'status': 'Active'},
    {'name': 'Finance', 'desc': 'Tuition tracking, payments, invoices, ledgers, and staff payroll.', 'status': 'Active'},
    {'name': 'Transport', 'desc': 'Manage school buses, stops, student routes, and GPS telemetry.', 'status': 'Active'},
    {'name': 'Hostel', 'desc': 'Student boarding, room allocations, wardens, and logs.', 'status': 'Active'},
    {'name': 'Resources', 'desc': 'Library catalogs, book borrowing registry, and resources.', 'status': 'Active'},
    {'name': 'HR', 'desc': 'Staff recruitment, salary ledgering, leaves, and attendance.', 'status': 'Active'},
  ];
  late List<Map<String, dynamic>> _categoriesList;

  @override
  void initState() {
    super.initState();
    _categoriesList = List<Map<String, dynamic>>.from(_predefinedCategories);
    _fetchData();
  }

  void _showCategoryFormDialog({Map<String, dynamic>? category}) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: isEdit ? category['name'] : '');
    final descController = TextEditingController(text: isEdit ? (category['desc'] ?? category['description'] ?? '') : '');
    String status = isEdit ? category['status'] : 'Active';

    showDialog(
      context: context,
      builder: (context) {
        final textPrimary = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
        return AlertDialog(
          title: Text(isEdit ? 'Edit Category' : 'Create Category', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Academics'),
                  enabled: !isEdit,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe this category'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['Active', 'Inactive'].map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) status = val;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              onPressed: () {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  _showSnackBar('Category name is required', isError: true);
                  return;
                }
                
                Future<void> saveProcess() async {
                  try {
                    if (isEdit) {
                      final res = await ApiService().put(
                        '/admin/schools/modules/categories/${category['name']}',
                        {
                          'description': desc,
                          'status': status,
                        },
                      );
                      if (res['success'] == true) {
                        _showSnackBar('Category updated successfully');
                        _fetchData();
                      } else {
                        _showSnackBar(res['detail'] ?? 'Failed to update category', isError: true);
                      }
                    } else {
                      final res = await ApiService().post(
                        '/admin/schools/modules/categories',
                        {
                          'name': name,
                          'description': desc,
                          'status': status,
                        },
                      );
                      if (res['success'] == true) {
                        _showSnackBar('Category created successfully');
                        _fetchData();
                      } else {
                        _showSnackBar(res['detail'] ?? 'Failed to create category', isError: true);
                      }
                    }
                  } catch (e) {
                    _showSnackBar('Error saving category: $e', isError: true);
                  }
                }
                saveProcess();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDependencyWarningDialog({
    required String title,
    required String subtitle,
    required String categoryName,
    required List<dynamic> dependentModules,
    required String instruction,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        final cardColor = isDark ? const Color(0xFF1E2540) : Colors.white;
        final textPrimary = isDark ? Colors.white : Colors.black87;
        final textSecondary = isDark ? Colors.white70 : Colors.black54;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 450,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFEF4444),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                      Text(
                        subtitle,
                        style: GoogleFonts.dmSans(
                          color: textPrimary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dependent Modules list styled as high-fidelity cards
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: dependentModules.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final module = dependentModules[index];
                            final name = module['name'] ?? 'Unknown Module';
                            final description = module['description'] ?? '';
                            final moduleIcon = module['icon'] ?? 'extension';
                            
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getModuleIcon(moduleIcon), size: 16, color: const Color(0xFF6366F1)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.dmSans(
                                            color: textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            description,
                                            style: GoogleFonts.dmSans(
                                              color: textSecondary,
                                              fontSize: 10,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Text(
                        instruction,
                        style: GoogleFonts.dmSans(
                          color: textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Actions Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Acknowledge',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteCategory(Map<String, dynamic> category) {
    final catName = category['name'];
    final dependentModules = _modules.where((m) => m['category'] == catName).toList();

    if (dependentModules.isNotEmpty) {
      _showDependencyWarningDialog(
        title: 'Cannot Delete Category',
        subtitle: 'The category "$catName" cannot be deleted because it contains the following active module(s):',
        categoryName: catName,
        dependentModules: dependentModules,
        instruction: 'Please reassign these modules to another category or delete them before deleting this category.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Category', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete the category "${category['name']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () {
                Future<void> deleteProcess() async {
                  try {
                    final res = await ApiService().delete('/admin/schools/modules/categories/${category['name']}');
                    if (res['success'] == true) {
                      _showSnackBar('Category deleted successfully');
                      _fetchData();
                    } else {
                      _showSnackBar(res['detail'] ?? 'Failed to delete category', isError: true);
                    }
                  } catch (e) {
                    _showSnackBar('Error deleting category: $e', isError: true);
                  }
                }
                deleteProcess();
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final schoolsRes = await ApiService().get('/admin/schools', useCache: false);
      final modulesRes = await ApiService().get('/admin/schools/modules/all', useCache: false);
      final requestsRes = await ApiService().get('/admin/schools/modules/requests', useCache: false);
      final categoriesRes = await ApiService().get('/admin/schools/modules/categories', useCache: false);

      if (schoolsRes['success'] == true && modulesRes['success'] == true) {
        setState(() {
          _schools = schoolsRes['data']['schools'] as List<dynamic>? ?? [];
          _modules = modulesRes['data'] as List<dynamic>? ?? [];
          
          if (requestsRes['success'] == true) {
            _requests = requestsRes['data'] as List<dynamic>? ?? [];
            if (_requests.isNotEmpty && _selectedRequest == null) {
              _selectedRequest = _requests[0];
            }
          }

          if (categoriesRes['success'] == true && categoriesRes['data'] != null && (categoriesRes['data'] as List).isNotEmpty) {
            _categoriesList = List<Map<String, dynamic>>.from(
              (categoriesRes['data'] as List).map((c) {
                final map = Map<String, dynamic>.from(c);
                map['desc'] = map['description'] ?? map['desc'] ?? '';
                return map;
              })
            );
          } else {
            _categoriesList = List<Map<String, dynamic>>.from(_predefinedCategories);
          }

          // Initialize defaults for right sidebar selections
          if (_modules.isNotEmpty && _selectedModule == null) {
            _selectModule(_modules[0]);
          }
          if (_categoriesList.isNotEmpty && _selectedCategory == null) {
            _selectedCategory = _categoriesList[0];
          }

          // Sync Assign Modules tab selection
          if (_schools.isNotEmpty && _selectedSchoolId == null) {
            _selectSchoolForAssign(_schools[0]['id']);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load module configuration: $e', isError: true);
    }
  }

  void _selectSchoolForAssign(String schoolId) {
    setState(() {
      _selectedSchoolId = schoolId;
      _assignTabCheckedModuleIds.clear();
      _assignTabOriginalModuleIds.clear();
      final school = _schools.firstWhere((s) => s['id'] == schoolId, orElse: () => null);
      if (school != null) {
        final toggles = school['module_toggles'] as Map<String, dynamic>? ?? {};
        toggles.forEach((key, val) {
          if (val == true) {
            _assignTabCheckedModuleIds.add(key);
            _assignTabOriginalModuleIds.add(key);
          }
        });
      }
    });
  }

  Future<void> _updateRequestStatus(String requestId, String status) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().put('/admin/schools/modules/requests/$requestId', {
        'status': status,
      });
      if (res['success'] == true) {
        _showSnackBar('Request status updated to $status successfully.');
        if (_selectedRequest?['id'] == requestId) {
          _selectedRequest = null;
        }
        await _fetchData();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to update request: $e', isError: true);
    }
  }

  void _selectModule(Map<String, dynamic> module) {
    setState(() {
      _selectedModule = module;
      _assignedSchoolIds.clear();
      final moduleId = module['id'];
      for (var school in _schools) {
        final toggles = school['module_toggles'] as Map<String, dynamic>? ?? {};
        if (toggles[moduleId] == true) {
          _assignedSchoolIds.add(school['id'] as String);
        }
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _saveModule(String? id, Map<String, dynamic> data) async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (id == null) {
        await ApiService().post('/admin/schools/modules/all', data);
        _showSnackBar('Module created successfully');
      } else {
        await ApiService().put('/admin/schools/modules/all/$id', data);
        _showSnackBar('Module updated successfully');
      }
      await _fetchData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        _showSnackBar('Failed to save module: $e', isError: true);
      }
    }
  }

  Future<void> _deleteModule(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await ApiService().delete('/admin/schools/modules/all/$id');
      _showSnackBar('Module deleted successfully');
      if (_selectedModule?['id'] == id) {
        _selectedModule = null;
      }
      await _fetchData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        _showSnackBar('Failed to delete module: $e', isError: true);
      }
    }
  }

  Future<void> _updateModuleAssignment() async {
    if (_selectedModule == null) return;
    final moduleId = _selectedModule!['id'];

    setState(() {
      _isLoading = true;
    });

    int updatedCount = 0;
    try {
      for (var school in _schools) {
        final schoolId = school['id'];
        final toggles = Map<String, dynamic>.from(school['module_toggles'] ?? {});
        final isCurrentlyAssigned = toggles[moduleId] == true;
        final shouldBeAssigned = _assignedSchoolIds.contains(schoolId);

        if (isCurrentlyAssigned != shouldBeAssigned) {
          toggles[moduleId] = shouldBeAssigned;
          await ApiService().put('/admin/schools/$schoolId', {
            'module_toggles': toggles,
          });
          school['module_toggles'] = toggles;
          updatedCount++;
        }
      }

      _showSnackBar('Successfully updated module assignments for $updatedCount institutions.');
    } catch (e) {
      _showSnackBar('Failed to update assignments: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _fetchData();
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
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_outlined,
                    color: Color(0xFFEF4444),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Deactivation Blocked',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This module cannot be deactivated or deleted because it is currently active for one or more institutions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.dmSans(
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
                            color: const Color(0xFFEF4444).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.15),
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
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF4444),
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
                          style: GoogleFonts.dmSans(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
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

  void _showEditModuleDialog([Map<String, dynamic>? module]) {
    final isNew = module == null;
    final idController = TextEditingController(text: isNew ? '' : module['id']);
    final nameController = TextEditingController(text: isNew ? '' : module['name']);
    final descController = TextEditingController(text: isNew ? '' : module['description'] ?? '');
    final iconController = TextEditingController(text: isNew ? 'extension' : module['icon'] ?? 'extension');
    final versionController = TextEditingController(text: isNew ? 'v1.0.0' : module['version'] ?? 'v1.0.0');
    final devController = TextEditingController(text: isNew ? 'School ERP Team' : module['developed_by'] ?? 'School ERP Team');
    
    String selectedCategory = isNew ? 'Core' : module['category'] ?? 'Core';
    String selectedType = isNew ? 'Feature' : module['type'] ?? 'Feature';

    List<dynamic> screensList = isNew ? [] : (module['screens'] as List<dynamic>? ?? []);
    List<dynamic> endpointsList = isNew ? [] : (module['endpoints'] as List<dynamic>? ?? []);
    final screensController = TextEditingController(text: screensList.join(', '));
    final endpointsController = TextEditingController(text: endpointsList.join(', '));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              backgroundColor: theme.scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isNew ? 'Create Master Module' : 'Edit Master Module',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      TextField(
                        controller: idController,
                        enabled: isNew,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Module ID / Key',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Module Name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        dropdownColor: theme.cardColor,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        items: _categoriesList.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['name'],
                            child: Text(c['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateBuilder(() => selectedCategory = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        dropdownColor: theme.cardColor,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        items: ['System', 'Feature'].map((t) {
                          return DropdownMenuItem<String>(
                            value: t,
                            child: Text(t),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateBuilder(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: versionController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Version',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: devController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Developer Name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: iconController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Material Icon Name',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: screensController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Controlled Screens (comma separated)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: endpointsController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Controlled Endpoints (comma separated)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final id = idController.text.trim();
                    final name = nameController.text.trim();
                    if (id.isEmpty || name.isEmpty) {
                      _showSnackBar('ID and Name are required', isError: true);
                      return;
                    }

                    final data = {
                      'id': id,
                      'name': name,
                      'description': descController.text.trim(),
                      'icon': iconController.text.trim(),
                      'category': selectedCategory,
                      'type': selectedType,
                      'version': versionController.text.trim(),
                      'developed_by': devController.text.trim(),
                      'screens': screensController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      'endpoints': endpointsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    };

                    Navigator.pop(context);
                    _saveModule(isNew ? null : module['id'], data);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final textMuted = isDark ? Colors.white30 : Colors.black38;
    final accentColor = const Color(0xFF6366F1);

    // Dynamic stats calculations
    final totalModules = _modules.length;
    final activeModules = _modules.where((m) => m['is_enabled'] == true).length;
    final disabledModules = totalModules - activeModules;
    final totalSchools = _schools.length;

    // Filters logic
    final filteredModules = _modules.where((m) {
      if (_searchQuery.isNotEmpty) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        final desc = (m['description'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) return false;
      }
      if (_selectedCategoryFilter != 'All' && m['category'] != _selectedCategoryFilter) return false;
      if (_selectedStatusFilter != 'All') {
        final isEnabled = _selectedStatusFilter == 'Active';
        if (m['is_enabled'] != isEnabled) return false;
      }
      if (_selectedTypeFilter != 'All' && m['type'] != _selectedTypeFilter) return false;
      return true;
    }).toList();

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    _buildHeader(isDark, textPrimary, textSecondary, accentColor),
                    const SizedBox(height: 24),

                    // Navigation Tabs
                    _buildNavigationTabs(isDark, textPrimary, textSecondary, borderColor),
                    const SizedBox(height: 20),

                    // Render content based on active tab
                    if (_activeTab == 'All Modules') ...[
                      _buildMetricsRow(isDark, cardBg, borderColor, textPrimary, textSecondary, totalModules, activeModules, disabledModules, totalSchools),
                      const SizedBox(height: 24),
                      _buildSplitViewLayout(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filteredModules),
                    ] else if (_activeTab == 'Module Categories') ...[
                      _buildCategoriesMetricsRow(isDark, cardBg, borderColor, textPrimary, textSecondary),
                      const SizedBox(height: 24),
                      _buildCategoriesSplitView(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                    ] else if (_activeTab == 'Assign Modules') ...[
                      _buildAssignModulesView(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                    ] else if (_activeTab == 'Module Requests') ...[
                      _buildModuleRequestsView(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modules Management',
              style: GoogleFonts.outfit(
                color: textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure system modules, organize categories, and assign them to institutions.',
              style: GoogleFonts.dmSans(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_activeTab == 'Module Categories') {
              _showCategoryFormDialog();
            } else {
              _showEditModuleDialog();
            }
          },
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: Text(
            _activeTab == 'Module Categories' ? 'Create New Category' : 'Create New Module',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationTabs(bool isDark, Color textPrimary, Color textSecondary, Color borderColor) {
    final tabs = ['All Modules', 'Module Categories', 'Assign Modules', 'Module Requests'];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          return InkWell(
            onTap: () {
              setState(() {
                _activeTab = tab;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: GoogleFonts.outfit(
                  color: isSelected ? textPrimary : textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricsRow(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, int total, int active, int disabled, int schools) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Total Modules', '$total', 'All system modules', Icons.dashboard_outlined, const Color(0xFF3B82F6), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Active Modules', '$active', 'Enabled and in use', Icons.check_circle_outline, const Color(0xFF10B981), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Disabled Modules', '$disabled', 'Currently disabled', Icons.pause_circle_outline, const Color(0xFFF59E0B), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Assigned Institutions', '$schools', 'Have module access', Icons.school_outlined, const Color(0xFF8B5CF6), cardBg, borderColor, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, String desc, IconData icon, Color color, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(value, style: GoogleFonts.outfit(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: GoogleFonts.dmSans(color: textSecondary.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitViewLayout(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor, List<dynamic> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 1150;
        if (isLargeScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildLeftTableColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filtered),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 340,
                child: _buildRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildLeftTableColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filtered),
              const SizedBox(height: 24),
              _buildRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
            ],
          );
        }
      },
    );
  }

  Widget _buildLeftTableColumn(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor, List<dynamic> filtered) {
    final totalFiltered = filtered.length;
    final maxPage = (totalFiltered / _pageSize).ceil();
    final displayPage = _currentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _currentPage;
    final startIndex = (displayPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > totalFiltered ? totalFiltered : startIndex + _pageSize;
    
    final paginated = filtered.isEmpty ? <dynamic>[] : filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter toolbar
          _buildFilterToolbar(isDark, cardBg, borderColor, textPrimary, textSecondary),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                _buildTableHeaderColumn('Module Name', textSecondary, width: 300),
                _buildTableHeaderColumn('Category', textSecondary, width: 120),
                _buildTableHeaderColumn('Type', textSecondary, width: 100),
                _buildTableHeaderColumn('Status', textSecondary, width: 150),
                _buildTableHeaderColumn('Assigned Inst.', textSecondary, width: 140),
                _buildTableHeaderColumn('Actions', textSecondary, width: 120),
              ],
              rows: paginated.map((module) {
                final isSelected = _selectedModule?['id'] == module['id'];
                final id = module['id'] ?? '';
                final name = module['name'] ?? 'Module Name';
                final desc = module['description'] ?? '';
                final category = module['category'] ?? 'Core';
                final type = module['type'] ?? 'Feature';
                final isEnabled = module['is_enabled'] ?? true;
                
                // Calculate assigned schools
                final assignedCount = _schools.where((s) {
                  final toggles = s['module_toggles'] as Map<String, dynamic>? ?? {};
                  return toggles[id] == true;
                }).length;

                final IconData icon = _getModuleIcon(module['icon']);
                Color catColor = _getCategoryColor(category);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) => _selectModule(module),
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.dmSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    desc,
                                    style: GoogleFonts.dmSans(color: textMuted, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: catColor.withOpacity(0.24)),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.dmSans(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          type,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEnabled ? 'Active' : 'Disabled',
                              style: GoogleFonts.dmSans(
                                color: isEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: isEnabled,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (val) => _saveModule(id, {'is_enabled': val}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          '$assignedCount / ${_schools.length}',
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              color: accentColor,
                              onPressed: () => _selectModule(module),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: const Color(0xFF10B981),
                              onPressed: () => _showEditModuleDialog(module),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: const Color(0xFFEF4444),
                              onPressed: () => _deleteModule(id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          // Pagination footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered modules',
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 16),
                      color: displayPage > 1 ? textPrimary : textMuted,
                      onPressed: displayPage > 1
                          ? () => setState(() => _currentPage = displayPage - 1)
                          : null,
                    ),
                    ...List.generate(maxPage, (index) {
                      final pageNum = index + 1;
                      final isCurrent = pageNum == displayPage;
                      if (maxPage > 5 && (pageNum - displayPage).abs() > 2 && pageNum != 1 && pageNum != maxPage) {
                        if (pageNum == 2 || pageNum == maxPage - 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text('...', style: TextStyle(color: textMuted)),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () => setState(() => _currentPage = pageNum),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pageNum.toString(),
                            style: GoogleFonts.dmSans(
                              color: isCurrent ? Colors.white : textSecondary,
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 16),
                      color: displayPage < maxPage ? textPrimary : textMuted,
                      onPressed: displayPage < maxPage
                          ? () => setState(() => _currentPage = displayPage + 1)
                          : null,
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _pageSize,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: [5, 10, 20, 50].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val / page'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildTableHeaderColumn(String label, Color textSecondary, {required double width}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          style: GoogleFonts.dmSans(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildFilterToolbar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search modules by name or description...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'Category',
            _selectedCategoryFilter,
            ['All', ..._categoriesList.map((c) => c['name'])],
            (val) => setState(() => _selectedCategoryFilter = val!),
            cardBg,
            textSecondary,
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'Status',
            _selectedStatusFilter,
            ['All', 'Active', 'Disabled'],
            (val) => setState(() => _selectedStatusFilter = val!),
            cardBg,
            textSecondary,
          ),
          const SizedBox(width: 12),
          _buildFilterDropdown(
            'Type',
            _selectedTypeFilter,
            ['All', 'System', 'Feature'],
            (val) => setState(() => _selectedTypeFilter = val!),
            cardBg,
            textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, Color cardBg, Color textSecondary) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: cardBg,
          style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary, fontWeight: FontWeight.bold),
          items: items.map((i) {
            return DropdownMenuItem<String>(
              value: i,
              child: Text(i == 'All' ? 'All ${label}s' : i),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRightSidebar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_selectedModule == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            'Select a module to view details.',
            style: GoogleFonts.dmSans(color: textMuted),
          ),
        ),
      );
    }

    final module = _selectedModule!;
    final name = module['name'] ?? 'Module details';
    final id = module['id'] ?? '';
    final category = module['category'] ?? 'Core';
    final desc = module['description'] ?? 'No description provided.';
    final type = module['type'] ?? 'Feature';
    final version = module['version'] ?? 'v1.0.0';
    final dev = module['developed_by'] ?? 'School ERP Team';
    final created = module['created_at'] != null ? module['created_at'].toString().split('T')[0] : 'Unknown';
    final isEnabled = module['is_enabled'] ?? true;

    // Filter school checkboxes based on search query
    final filteredSchools = _schools.where((s) {
      if (_schoolSearchQuery.isEmpty) return true;
      final schoolName = s['name'].toString().toLowerCase();
      return schoolName.contains(_schoolSearchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // 1. Module Details card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Module Details', style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getModuleIcon(module['icon']), color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                              child: Text(category, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEnabled ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isEnabled ? 'Active' : 'Disabled',
                                style: GoogleFonts.dmSans(
                                  color: isEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(desc, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 16),
              _buildDetailSidebarRow('Module Type', type, textSecondary, textPrimary),
              _buildDetailSidebarRow('Version', version, textSecondary, textPrimary),
              _buildDetailSidebarRow('Created On', created, textSecondary, textPrimary),
              _buildDetailSidebarRow('Developed By', dev, textSecondary, textPrimary),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showEditModuleDialog(module),
                      child: Text('Edit Module', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEnabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => _saveModule(id, {'is_enabled': !isEnabled}),
                      child: Text(isEnabled ? 'Disable Module' : 'Enable Module', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Assign to Institutions card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign to Institutions', style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Search institutions
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.dmSans(fontSize: 12, color: textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search institutions...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _schoolSearchQuery = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredSchools.length,
                  itemBuilder: (context, index) {
                    final school = filteredSchools[index];
                    final sId = school['id'] as String;
                    final sName = school['name'] ?? '';
                    final isChecked = _assignedSchoolIds.contains(sId);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isChecked) {
                            _assignedSchoolIds.remove(sId);
                          } else {
                            _assignedSchoolIds.add(sId);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _assignedSchoolIds.add(sId);
                                  } else {
                                    _assignedSchoolIds.remove(sId);
                                  }
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sName, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(school['address'] ?? 'UP, India', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: _updateModuleAssignment,
                  child: Text('Update Assignment', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSidebarRow(String label, String value, Color textSecondary, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11)),
          Text(value, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: MODULE CATEGORIES
  // ============================================================

  Widget _buildCategoriesMetricsRow(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    // Dynamic counts
    final totalCats = _categoriesList.length;
    final activeCats = _categoriesList.where((c) => c['status'] == 'Active').length;
    final inactiveCats = totalCats - activeCats;
    final totalMods = _modules.length;

    return Row(
      children: [
        Expanded(child: _buildMetricCard('Total Categories', '$totalCats', 'All module categories', Icons.folder_open_outlined, const Color(0xFF3B82F6), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Active Categories', '$activeCats', 'Enabled and in use', Icons.check_circle_outline, const Color(0xFF10B981), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Inactive Categories', '$inactiveCats', 'Currently disabled', Icons.pause_circle_outline, const Color(0xFFF59E0B), cardBg, borderColor, textPrimary, textSecondary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('Total Modules', '$totalMods', 'Across all categories', Icons.dashboard_outlined, const Color(0xFF8B5CF6), cardBg, borderColor, textPrimary, textSecondary)),
      ],
    );
  }

  Widget _buildCategoriesSplitView(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 1150;
        if (isLargeScreen) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildCategoriesTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 340,
                child: _buildCategoriesRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildCategoriesTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
              const SizedBox(height: 24),
              _buildCategoriesRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
            ],
          );
        }
      },
    );
  }

  Widget _buildCategoriesTable(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    final filteredCategories = _categoriesList.where((cat) {
      if (_categoriesSearchQuery.isEmpty) return true;
      return cat['name'].toString().toLowerCase().contains(_categoriesSearchQuery.toLowerCase());
    }).toList();

    final totalFiltered = filteredCategories.length;
    final maxPage = (totalFiltered / _categoriesPageSize).ceil();
    final displayPage = _categoriesCurrentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _categoriesCurrentPage;
    final startIndex = (displayPage - 1) * _categoriesPageSize;
    final endIndex = startIndex + _categoriesPageSize > totalFiltered ? totalFiltered : startIndex + _categoriesPageSize;

    final paginated = filteredCategories.isEmpty ? <dynamic>[] : filteredCategories.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search categories by name...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _categoriesSearchQuery = val;
                                _categoriesCurrentPage = 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Create Category', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => _showCategoryFormDialog(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 24,
              columns: [
                _buildTableHeaderColumn('Category Name', textSecondary, width: 200),
                _buildTableHeaderColumn('Description', textSecondary, width: 300),
                _buildTableHeaderColumn('Status', textSecondary, width: 120),
                _buildTableHeaderColumn('Modules', textSecondary, width: 110),
                _buildTableHeaderColumn('Created On', textSecondary, width: 110),
                _buildTableHeaderColumn('Actions', textSecondary, width: 120),
              ],
              rows: paginated.map((cat) {
                final isSelected = _selectedCategory?['name'] == cat['name'];
                final name = cat['name'];
                final desc = cat['desc'] ?? cat['description'] ?? '';
                final status = cat['status'];
                final count = _modules.where((m) => m['category'] == name).length;

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Row(
                          children: [
                            const Icon(Icons.folder_open_outlined, size: 18, color: Color(0xFF8B5CF6)),
                            const SizedBox(width: 8),
                            Text(name, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 300,
                        child: Text(
                          desc,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Text(
                          '$count Modules',
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Text(
                          'May 15, 2023',
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              color: accentColor,
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: const Color(0xFF10B981),
                              onPressed: () => _showCategoryFormDialog(category: cat),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              color: const Color(0xFFEF4444),
                              onPressed: () => _deleteCategory(cat),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered categories',
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 16),
                      color: displayPage > 1 ? textPrimary : textMuted,
                      onPressed: displayPage > 1
                          ? () => setState(() => _categoriesCurrentPage = displayPage - 1)
                          : null,
                    ),
                    ...List.generate(maxPage, (index) {
                      final pageNum = index + 1;
                      final isCurrent = pageNum == displayPage;
                      if (maxPage > 5 && (pageNum - displayPage).abs() > 2 && pageNum != 1 && pageNum != maxPage) {
                        if (pageNum == 2 || pageNum == maxPage - 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text('...', style: TextStyle(color: textMuted)),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () => setState(() => _categoriesCurrentPage = pageNum),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pageNum.toString(),
                            style: GoogleFonts.dmSans(
                              color: isCurrent ? Colors.white : textSecondary,
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 16),
                      color: displayPage < maxPage ? textPrimary : textMuted,
                      onPressed: displayPage < maxPage
                          ? () => setState(() => _categoriesCurrentPage = displayPage + 1)
                          : null,
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _categoriesPageSize,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: [5, 10, 20, 50].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val / page'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _categoriesPageSize = val;
                        _categoriesCurrentPage = 1;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesRightSidebar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_selectedCategory == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            'Select a category to view details.',
            style: GoogleFonts.dmSans(color: textMuted),
          ),
        ),
      );
    }

    final cat = _selectedCategory!;
    final name = cat['name'];
    final desc = cat['desc'] ?? cat['description'] ?? '';
    final count = _modules.where((m) => m['category'] == name).length;

    // Calculate distributions for Categories donut chart
    final Map<String, int> catCounts = {};
    for (var c in _categoriesList) {
      final name = c['name'] as String;
      final cnt = _modules.where((m) => m['category'] == name).length;
      if (cnt > 0) {
        catCounts[name] = cnt;
      }
    }

    final List<Color> donutColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF14B8A6),
    ];

    return Column(
      children: [
        // Category Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category Details', style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_open_outlined, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$count Modules assigned', style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(desc, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, height: 1.4)),
              const SizedBox(height: 16),
              _buildDetailSidebarRow('Created On', 'May 15, 2023 10:30 AM', textSecondary, textPrimary),
              _buildDetailSidebarRow('Created By', 'School ERP Team', textSecondary, textPrimary),
              _buildDetailSidebarRow('Status', cat['status'] ?? 'Active', textSecondary, textPrimary),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showCategoryFormDialog(category: cat),
                      child: Text('Edit Category', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cat['status'] == 'Active' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final newStatus = cat['status'] == 'Active' ? 'Inactive' : 'Active';
                        if (newStatus == 'Inactive') {
                          final catName = cat['name'];
                          final dependentModules = _modules.where((m) => m['category'] == catName).toList();
                          if (dependentModules.isNotEmpty) {
                            _showDependencyWarningDialog(
                              title: 'Cannot Disable Category',
                              subtitle: 'The category "$catName" cannot be disabled because it contains the following active module(s):',
                              categoryName: catName,
                              dependentModules: dependentModules,
                              instruction: 'Please reassign these modules to another category or disable them first.',
                            );
                            return;
                          }
                        }

                        Future<void> toggleStatus() async {
                          try {
                            final res = await ApiService().put(
                              '/admin/schools/modules/categories/${cat['name']}',
                              {
                                'description': cat['desc'] ?? cat['description'] ?? '',
                                'status': newStatus,
                              },
                            );
                            if (res['success'] == true) {
                              _showSnackBar('Category status updated to $newStatus');
                              _fetchData();
                            } else {
                              _showSnackBar(res['detail'] ?? 'Failed to update category status', isError: true);
                            }
                          } catch (e) {
                            _showSnackBar('Error updating status: $e', isError: true);
                          }
                        }
                        toggleStatus();
                      },
                      child: Text(cat['status'] == 'Active' ? 'Disable Category' : 'Enable Category', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category Usage Chart Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category Usage', style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: CategoryDonutPainter(data: catCounts, colors: donutColors),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${_modules.length}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
                          Text('Modules', style: GoogleFonts.dmSans(fontSize: 9, color: textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: catCounts.keys.toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final label = e.value;
                  final count = catCounts[label]!;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: donutColors[idx % donutColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('$label ($count)', style: GoogleFonts.dmSans(fontSize: 10, color: textSecondary)),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 3: ASSIGN MODULES (PER SCHOOL TOGGLES)
  // ============================================================

  Widget _buildAssignModulesView(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_schools.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No schools registered in the system.',
            style: GoogleFonts.dmSans(color: textMuted),
          ),
        ),
      );
    }

    if (_selectedSchoolId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Step 1: Select Institution
    if (_assignStep == 1) {
      final filteredSchoolsList = _schools.where((s) {
        if (_schoolSearchQuery.isEmpty) return true;
        final name = s['name'].toString().toLowerCase();
        final addr = (s['address'] ?? '').toString().toLowerCase();
        final q = _schoolSearchQuery.toLowerCase();
        return name.contains(q) || addr.contains(q);
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select an Institution to Manage Module Access',
            style: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search institutions by name or location...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _schoolSearchQuery = val;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grid/List of schools
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 110,
            ),
            itemCount: filteredSchoolsList.length,
            itemBuilder: (context, index) {
              final school = filteredSchoolsList[index];
              final sId = school['id'];
              final name = school['name'] ?? 'Institution';
              final addr = school['address'] ?? 'UP, India';
              final logoUrl = school['logo_url']?.toString() ?? '';
              final assignedModulesCount = (school['module_toggles'] as Map<String, dynamic>? ?? {}).values.where((v) => v == true).length;

              return InkWell(
                onTap: () {
                  _selectSchoolForAssign(sId);
                  setState(() {
                    _assignStep = 2;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.dmSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              addr,
                              style: GoogleFonts.dmSans(color: textMuted, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                '$assignedModulesCount Modules Assigned',
                                style: GoogleFonts.dmSans(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // Step 2 & 3: Assign Wizard
    final school = _schools.firstWhere((s) => s['id'] == _selectedSchoolId, orElse: () => null);
    if (school == null) return const SizedBox.shrink();
    
    final schoolName = school['name'] ?? '';
    final schoolAddr = school['address'] ?? 'UP, India';
    final ownerName = school['owner_name'] ?? 'Mr. Rajesh Sharma';
    final ownerEmail = school['owner_email'] ?? 'principal@greenfield.edu.in';
    final maxStudents = school['max_students'] ?? 1000;
    
    // Filter modules for assignment selection
    final filteredAssignModules = _modules.where((m) {
      if (_assignModulesSearchQuery.isNotEmpty) {
        final name = (m['name'] ?? '').toString().toLowerCase();
        final desc = (m['description'] ?? '').toString().toLowerCase();
        final q = _assignModulesSearchQuery.toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) return false;
      }
      if (_assignModulesCategoryFilter != 'All' && m['category'] != _assignModulesCategoryFilter) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wizard Progress Header
        _buildWizardFlowHeader(isDark, textPrimary, textSecondary),
        const SizedBox(height: 20),

        // Selected Institution Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_outlined, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selected Institution', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(schoolName, style: GoogleFonts.outfit(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(schoolAddr, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact Person', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(ownerName, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(ownerEmail, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Limit', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('$maxStudents students', style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Modules', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${_assignTabOriginalModuleIds.length} Assigned', style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 14),
                label: Text('Change Institution', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onPressed: () => setState(() => _assignStep = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_assignStep == 2) ...[
          // STEP 2 Split View
          LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 1150;
              if (isLargeScreen) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildAssignModulesLeftTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filteredAssignModules),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 340,
                      child: _buildAssignModulesRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAssignModulesLeftTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filteredAssignModules),
                    const SizedBox(height: 24),
                    _buildAssignModulesRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                  ],
                );
              }
            },
          ),
        ] else ...[
          // STEP 3: Review & Confirm View
          _buildReviewAndConfirmView(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
        ],
      ],
    );
  }

  Widget _buildWizardFlowHeader(bool isDark, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        _buildWizardFlowStep(1, 'Select Institution', _assignStep > 1, _assignStep == 1, textPrimary, textSecondary),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        const SizedBox(width: 12),
        _buildWizardFlowStep(2, 'Select Modules', _assignStep > 2, _assignStep == 2, textPrimary, textSecondary),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        const SizedBox(width: 12),
        _buildWizardFlowStep(3, 'Review & Confirm', false, _assignStep == 3, textPrimary, textSecondary),
      ],
    );
  }

  Widget _buildWizardFlowStep(int index, String label, bool isDone, bool isActive, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF10B981) : (isActive ? const Color(0xFF4F46E5) : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: isDone ? const Color(0xFF10B981) : (isActive ? const Color(0xFF4F46E5) : Colors.grey)),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$index',
                    style: GoogleFonts.outfit(
                      color: isActive ? Colors.white : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: isActive || isDone ? textPrimary : textSecondary,
            fontSize: 13,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildAssignModulesLeftTable(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor, List<dynamic> filtered) {
    final totalFiltered = filtered.length;
    final maxPage = (totalFiltered / _assignPageSize).ceil();
    final displayPage = _assignCurrentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _assignCurrentPage;
    final startIndex = (displayPage - 1) * _assignPageSize;
    final endIndex = startIndex + _assignPageSize > totalFiltered ? totalFiltered : startIndex + _assignPageSize;

    final paginated = filtered.isEmpty ? <dynamic>[] : filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Toolbar filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search modules by name or description...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _assignModulesSearchQuery = val;
                                _assignCurrentPage = 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterDropdown(
                  'Category',
                  _assignModulesCategoryFilter,
                  ['All', ..._categoriesList.map((c) => c['name'])],
                  (val) => setState(() {
                    _assignModulesCategoryFilter = val!;
                    _assignCurrentPage = 1;
                  }),
                  cardBg,
                  textSecondary,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                _buildTableHeaderColumn('Module Name', textSecondary, width: 220),
                _buildTableHeaderColumn('Category', textSecondary, width: 100),
                _buildTableHeaderColumn('Type', textSecondary, width: 80),
                _buildTableHeaderColumn('Description', textSecondary, width: 260),
                _buildTableHeaderColumn('Status', textSecondary, width: 90),
                _buildTableHeaderColumn('Current Status', textSecondary, width: 110),
              ],
              rows: paginated.map((module) {
                final id = module['id'] ?? '';
                final name = module['name'] ?? '';
                final desc = module['description'] ?? '';
                final category = module['category'] ?? 'Core';
                final type = module['type'] ?? 'Feature';
                final isEnabled = module['is_enabled'] ?? true;
                final isChecked = _assignTabCheckedModuleIds.contains(id);
                final originalAssigned = _assignTabOriginalModuleIds.contains(id);

                final IconData icon = _getModuleIcon(module['icon']);
                Color catColor = _getCategoryColor(category);

                return DataRow(
                  selected: isChecked,
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _assignTabCheckedModuleIds.add(id);
                      } else {
                        _assignTabCheckedModuleIds.remove(id);
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Row(
                          children: [
                            Icon(icon, size: 18, color: accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.dmSans(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: catColor.withOpacity(0.24)),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.dmSans(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Text(
                          type,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 260,
                        child: Text(
                          desc,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEnabled ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isEnabled ? 'Active' : 'Disabled',
                            style: GoogleFonts.dmSans(
                              color: isEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: originalAssigned ? const Color(0xFF10B981).withOpacity(0.12) : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            originalAssigned ? 'Assigned' : 'Not Assigned',
                            style: GoogleFonts.dmSans(
                              color: originalAssigned ? const Color(0xFF10B981) : textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered modules',
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 16),
                      color: displayPage > 1 ? textPrimary : textMuted,
                      onPressed: displayPage > 1
                          ? () => setState(() => _assignCurrentPage = displayPage - 1)
                          : null,
                    ),
                    ...List.generate(maxPage, (index) {
                      final pageNum = index + 1;
                      final isCurrent = pageNum == displayPage;
                      if (maxPage > 5 && (pageNum - displayPage).abs() > 2 && pageNum != 1 && pageNum != maxPage) {
                        if (pageNum == 2 || pageNum == maxPage - 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text('...', style: TextStyle(color: textMuted)),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () => setState(() => _assignCurrentPage = pageNum),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pageNum.toString(),
                            style: GoogleFonts.dmSans(
                              color: isCurrent ? Colors.white : textSecondary,
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 16),
                      color: displayPage < maxPage ? textPrimary : textMuted,
                      onPressed: displayPage < maxPage
                          ? () => setState(() => _assignCurrentPage = displayPage + 1)
                          : null,
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _assignPageSize,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: [5, 10, 20, 50].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val / page'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _assignPageSize = val;
                        _assignCurrentPage = 1;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignModulesRightSidebar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    // Calculates
    final total = _modules.length;
    final assignedCount = _assignTabOriginalModuleIds.intersection(_assignTabCheckedModuleIds).length;
    final newlySelectedCount = _assignTabCheckedModuleIds.difference(_assignTabOriginalModuleIds).length;
    final notSelectedCount = total - _assignTabCheckedModuleIds.length;

    final donutColors = [
      const Color(0xFF10B981), // Green: Assigned
      const Color(0xFF8B5CF6), // Purple: Newly Selected
      const Color(0xFF64748B), // Slate: Not Selected
    ];

    return Column(
      children: [
        // 1. Assignment Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assignment Summary', style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: AssignmentSummaryDonutPainter(
                      assigned: assignedCount,
                      newlySelected: newlySelectedCount,
                      notSelected: notSelectedCount,
                      colors: donutColors,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${_assignTabCheckedModuleIds.length}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
                          Text('Selected', style: GoogleFonts.dmSans(fontSize: 9, color: textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSidebarLegendRow(donutColors[0], 'Assigned ($assignedCount)', 'Modules already assigned', textSecondary, textMuted),
              _buildSidebarLegendRow(donutColors[1], 'Newly Selected ($newlySelectedCount)', 'Modules will be assigned', textSecondary, textMuted),
              _buildSidebarLegendRow(donutColors[2], 'Not Selected ($notSelectedCount)', 'Modules not selected', textSecondary, textMuted),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              _buildDetailSidebarRow('Total Modules', '$total', textSecondary, textPrimary),
              _buildDetailSidebarRow('Currently Assigned', '${_assignTabOriginalModuleIds.length}', textSecondary, textPrimary),
              _buildDetailSidebarRow('Newly Selected', '$newlySelectedCount', textSecondary, textPrimary),
              _buildDetailSidebarRow('Total After Assignment', '${_assignTabCheckedModuleIds.length}', textSecondary, textPrimary),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Selected Modules List
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selected Modules (${_assignTabCheckedModuleIds.length})', style: GoogleFonts.outfit(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => setState(() => _assignTabCheckedModuleIds.clear()),
                    child: Text('Clear All', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: _assignTabCheckedModuleIds.map((mId) {
                    final module = _modules.firstWhere((m) => m['id'] == mId, orElse: () => null);
                    if (module == null) return const SizedBox.shrink();
                    final name = module['name'] ?? '';
                    final cat = module['category'] ?? 'Core';
                    final catColor = _getCategoryColor(cat);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(_getModuleIcon(module['icon']), size: 14, color: accentColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(name, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(cat, style: GoogleFonts.dmSans(color: catColor, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.close, size: 12, color: Colors.grey),
                            onPressed: () => setState(() => _assignTabCheckedModuleIds.remove(mId)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Quick Actions & Confirm Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Actions', style: GoogleFonts.outfit(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    for (var m in _modules) {
                      if (m['is_enabled'] == true) {
                        _assignTabCheckedModuleIds.add(m['id']);
                      }
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.select_all, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Select All Active Modules', style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => _assignTabCheckedModuleIds.clear()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.deselect, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Deselect All', style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _assignStep = 1),
                      child: Text('Cancel', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => setState(() => _assignStep = 3),
                      child: Text('Review & Confirm', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarLegendRow(Color color, String label, String desc, Color textSecondary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(desc, style: GoogleFonts.dmSans(color: textMuted, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewAndConfirmView(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    // Determine additions and removals
    final addedIds = _assignTabCheckedModuleIds.difference(_assignTabOriginalModuleIds);
    final removedIds = _assignTabOriginalModuleIds.difference(_assignTabCheckedModuleIds);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Changes Before Saving',
            style: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm the module access updates below. These modifications will immediately apply to all users of the selected institution.',
            style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Additions section
          _buildReviewSectionHeader('MODULES TO BE GRANTED ACCESS (${addedIds.length})', const Color(0xFF10B981)),
          const SizedBox(height: 8),
          if (addedIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('No new modules will be assigned.', style: GoogleFonts.dmSans(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
            )
          else
            _buildReviewList(addedIds, const Color(0xFF10B981), isDark, textPrimary, textSecondary),

          // Removals section
          _buildReviewSectionHeader('MODULES TO BE REVOKED ACCESS (${removedIds.length})', const Color(0xFFEF4444)),
          const SizedBox(height: 8),
          if (removedIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text('No assigned modules will be revoked.', style: GoogleFonts.dmSans(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
            )
          else
            _buildReviewList(removedIds, const Color(0xFFEF4444), isDark, textPrimary, textSecondary),

          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () => setState(() => _assignStep = 2),
                child: Text('Back to Select Modules', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    // Build toggles map
                    final toggles = <String, bool>{};
                    for (var m in _modules) {
                      final mId = m['id'] as String;
                      toggles[mId] = _assignTabCheckedModuleIds.contains(mId);
                    }
                    await ApiService().put('/admin/schools/$_selectedSchoolId', {
                      'module_toggles': toggles,
                    });
                    _showSnackBar('Institution module assignments updated successfully.');
                    setState(() {
                      _assignStep = 2;
                    });
                    await _fetchData();
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showSnackBar('Assignment update failed: $e', isError: true);
                  }
                },
                child: Text('Confirm & Save Access', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSectionHeader(String label, Color color) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildReviewList(Set<String> ids, Color color, bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: ids.map((mId) {
          final module = _modules.firstWhere((m) => m['id'] == mId, orElse: () => null);
          if (module == null) return const SizedBox.shrink();
          final name = module['name'] ?? '';
          final desc = module['description'] ?? '';

          return ListTile(
            dense: true,
            leading: Icon(_getModuleIcon(module['icon']), size: 16, color: color),
            title: Text(name, style: GoogleFonts.dmSans(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: Text(desc, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 10)),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // TAB 4: MODULE REQUESTS
  // ============================================================

  Widget _buildModuleRequestsView(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    // Calculates
    final totalRequests = _requests.length;
    final pendingCount = _requests.where((r) => r['status'] == 'Pending').length;
    final approvedCount = _requests.where((r) => r['status'] == 'Approved').length;
    final rejectedCount = _requests.where((r) => r['status'] == 'Rejected').length;

    // Filter requests
    final filteredRequests = _requests.where((r) {
      // 1. Sub-tab filter
      if (_requestsSubTab != 'All Requests') {
        final expectedStatus = _requestsSubTab.split(' ')[0]; // Pending, Approved, Rejected
        if (r['status'] != expectedStatus) return false;
      }
      // 2. Search query filter
      if (_requestsSearchQuery.isNotEmpty) {
        final reqId = (r['id'] ?? '').toString().toLowerCase();
        final requester = (r['requested_by_name'] ?? '').toString().toLowerCase();
        final schoolName = (r['schools']?['name'] ?? '').toString().toLowerCase();
        final moduleName = (r['modules']?['name'] ?? '').toString().toLowerCase();
        final q = _requestsSearchQuery.toLowerCase();
        if (!reqId.contains(q) && !requester.contains(q) && !schoolName.contains(q) && !moduleName.contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-tabs
        _buildRequestsSubTabs(isDark, textPrimary, textSecondary, borderColor, pendingCount, approvedCount, rejectedCount),
        const SizedBox(height: 16),

        // Metric Cards Row
        Row(
          children: [
            Expanded(child: _buildMetricCard('Total Requests', '$totalRequests', 'All time requests', Icons.receipt_long_outlined, const Color(0xFF3B82F6), cardBg, borderColor, textPrimary, textSecondary)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Pending Requests', '$pendingCount', 'Awaiting review', Icons.hourglass_empty_outlined, const Color(0xFFF59E0B), cardBg, borderColor, textPrimary, textSecondary)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Approved Requests', '$approvedCount', 'Approved & granted', Icons.check_circle_outline, const Color(0xFF10B981), cardBg, borderColor, textPrimary, textSecondary)),
            const SizedBox(width: 16),
            Expanded(child: _buildMetricCard('Rejected Requests', '$rejectedCount', 'Not approved', Icons.highlight_off_outlined, const Color(0xFFEF4444), cardBg, borderColor, textPrimary, textSecondary)),
          ],
        ),
        const SizedBox(height: 24),

        // Split view
        LayoutBuilder(
          builder: (context, constraints) {
            final isLargeScreen = constraints.maxWidth > 1150;
            if (isLargeScreen) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildRequestsTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filteredRequests),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 340,
                    child: _buildRequestsRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildRequestsTable(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, filteredRequests),
                  const SizedBox(height: 24),
                  _buildRequestsRightSidebar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildRequestsSubTabs(bool isDark, Color textPrimary, Color textSecondary, Color borderColor, int pending, int approved, int rejected) {
    final subTabs = [
      'All Requests',
      'Pending ($pending)',
      'Approved ($approved)',
      'Rejected ($rejected)',
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: subTabs.map((tab) {
          final isSelected = _requestsSubTab == tab;
          return InkWell(
            onTap: () {
              setState(() {
                _requestsSubTab = tab;
                _requestsCurrentPage = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: GoogleFonts.outfit(
                  color: isSelected ? textPrimary : textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestsTable(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor, List<dynamic> filtered) {
    final totalFiltered = filtered.length;
    final maxPage = (totalFiltered / _requestsPageSize).ceil();
    final displayPage = _requestsCurrentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _requestsCurrentPage;
    final startIndex = (displayPage - 1) * _requestsPageSize;
    final endIndex = startIndex + _requestsPageSize > totalFiltered ? totalFiltered : startIndex + _requestsPageSize;

    final paginated = filtered.isEmpty ? <dynamic>[] : filtered.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search requests by ID, school, module or requester...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _requestsSearchQuery = val;
                                _requestsCurrentPage = 1;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 20,
              columns: [
                _buildTableHeaderColumn('Request ID', textSecondary, width: 110),
                _buildTableHeaderColumn('Module Name', textSecondary, width: 160),
                _buildTableHeaderColumn('Institution', textSecondary, width: 180),
                _buildTableHeaderColumn('Requested By', textSecondary, width: 160),
                _buildTableHeaderColumn('Requested On', textSecondary, width: 100),
                _buildTableHeaderColumn('Status', textSecondary, width: 90),
                _buildTableHeaderColumn('Actions', textSecondary, width: 80),
              ],
              rows: paginated.map((req) {
                final isSelected = _selectedRequest?['id'] == req['id'];
                final id = req['id'] ?? '';
                final moduleName = req['modules']?['name'] ?? 'Module';
                final moduleIcon = req['modules']?['icon'] ?? 'extension';
                final schoolName = req['schools']?['name'] ?? 'School';
                final requesterName = req['requested_by_name'] ?? '';
                final requesterEmail = req['requested_by_email'] ?? '';
                final requestedOnStr = req['created_at'] != null ? req['created_at'].toString().split('T')[0] : '';
                final status = req['status'] ?? 'Pending';

                Color statusColor = const Color(0xFFF59E0B);
                if (status == 'Approved') statusColor = const Color(0xFF10B981);
                if (status == 'Rejected') statusColor = const Color(0xFFEF4444);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() {
                      _selectedRequest = req;
                    });
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Text(
                          id,
                          style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            Icon(_getModuleIcon(moduleIcon), size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                moduleName,
                                style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          schoolName,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(requesterName, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            Text(requesterEmail, style: GoogleFonts.dmSans(color: textMuted, fontSize: 10), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          requestedOnStr,
                          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.dmSans(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                              color: accentColor,
                              onPressed: () {
                                setState(() {
                                  _selectedRequest = req;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered requests',
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 16),
                      color: displayPage > 1 ? textPrimary : textMuted,
                      onPressed: displayPage > 1
                          ? () => setState(() => _requestsCurrentPage = displayPage - 1)
                          : null,
                    ),
                    ...List.generate(maxPage, (index) {
                      final pageNum = index + 1;
                      final isCurrent = pageNum == displayPage;
                      if (maxPage > 5 && (pageNum - displayPage).abs() > 2 && pageNum != 1 && pageNum != maxPage) {
                        if (pageNum == 2 || pageNum == maxPage - 1) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text('...', style: TextStyle(color: textMuted)),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                      return InkWell(
                        onTap: () => setState(() => _requestsCurrentPage = pageNum),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? accentColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pageNum.toString(),
                            style: GoogleFonts.dmSans(
                              color: isCurrent ? Colors.white : textSecondary,
                              fontSize: 12,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 16),
                      color: displayPage < maxPage ? textPrimary : textMuted,
                      onPressed: displayPage < maxPage
                          ? () => setState(() => _requestsCurrentPage = displayPage + 1)
                          : null,
                    ),
                  ],
                ),
                DropdownButton<int>(
                  value: _requestsPageSize,
                  dropdownColor: cardBg,
                  style: TextStyle(color: textPrimary, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  items: [5, 10, 20, 50].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val / page'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _requestsPageSize = val;
                        _requestsCurrentPage = 1;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsRightSidebar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_selectedRequest == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            'Select a request to view details.',
            style: GoogleFonts.dmSans(color: textMuted),
          ),
        ),
      );
    }

    final req = _selectedRequest!;
    final id = req['id'] ?? '';
    final moduleName = req['modules']?['name'] ?? '';
    final moduleIcon = req['modules']?['icon'] ?? 'extension';
    final moduleType = req['modules']?['type'] ?? 'Feature';
    final schoolName = req['schools']?['name'] ?? '';
    final schoolAddress = req['schools']?['address'] ?? 'UP, India';
    final requester = req['requested_by_name'] ?? '';
    final email = req['requested_by_email'] ?? '';
    final requestedOn = req['created_at'] != null ? req['created_at'].toString().split('T')[0] : '';
    final reason = req['reason'] ?? '';
    final notes = req['additional_notes'] ?? '';
    final requiredFor = req['required_for'] ?? '';
    final expectedUsers = req['expected_users'] ?? '';
    final priority = req['priority'] ?? 'Medium';
    final status = req['status'] ?? 'Pending';

    final isPending = status == 'Pending';

    Color priorityColor = const Color(0xFFF59E0B);
    if (priority == 'High') priorityColor = const Color(0xFFEF4444);
    if (priority == 'Low') priorityColor = const Color(0xFF3B82F6);

    return Column(
      children: [
        // 1. Request Details Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Request Details', style: GoogleFonts.outfit(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: priorityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(status, style: GoogleFonts.dmSans(color: priorityColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getModuleIcon(moduleIcon), color: accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(moduleName, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(moduleType, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailSidebarRow('Institution', schoolName, textSecondary, textPrimary),
              _buildDetailSidebarRow('Location', schoolAddress, textSecondary, textPrimary),
              _buildDetailSidebarRow('Requested By', requester, textSecondary, textPrimary),
              _buildDetailSidebarRow('Email', email, textSecondary, textPrimary),
              _buildDetailSidebarRow('Requested On', requestedOn, textSecondary, textPrimary),
              _buildDetailSidebarRow('Required For', requiredFor, textSecondary, textPrimary),
              _buildDetailSidebarRow('Expected Users', expectedUsers, textSecondary, textPrimary),
              _buildDetailSidebarRow('Priority', priority, textSecondary, priorityColor),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Text('Reason for Request', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(reason, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, height: 1.4)),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Additional Notes', style: GoogleFonts.dmSans(color: textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(notes, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, height: 1.4)),
              ],
              const SizedBox(height: 16),
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () => _updateRequestStatus(id, 'Approved'),
                        child: Text('Approve Request', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () => _updateRequestStatus(id, 'Rejected'),
                        child: Text('Reject Request', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    _selectSchoolForAssign(req['school_id']);
                    setState(() {
                      _activeTab = 'Assign Modules';
                      _assignStep = 2;
                    });
                  },
                  child: Text('View Institution', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 2. Request Activity Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request Activity', style: GoogleFonts.outfit(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTimelineItem('Request Submitted', '$requestedOn 10:30 AM', 'By $requester', Colors.green, true),
              _buildTimelineItem('Under Review', '$requestedOn 11:15 AM', 'Automatically assigned status', Colors.purple, true),
              _buildTimelineItem(
                isPending ? 'Pending Review' : 'Status Resolved',
                isPending ? '$requestedOn 11:15 AM' : '$requestedOn 12:00 PM',
                isPending ? 'Awaiting final action' : 'Status is set to $status',
                isPending ? Colors.amber : (status == 'Approved' ? Colors.green : Colors.red),
                false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(String title, String time, String desc, Color color, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 36,
                color: Colors.white10,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(time, style: GoogleFonts.dmSans(fontSize: 8, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 2),
              Text(desc, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  IconData _getModuleIcon(dynamic iconName) {
    switch (iconName?.toString().toLowerCase()) {
      case 'payment':
      case 'attach_money':
      case 'finance':
        return Icons.attach_money_outlined;
      case 'directions_bus':
      case 'bus':
        return Icons.directions_bus_outlined;
      case 'local_library':
      case 'library':
        return Icons.local_library_outlined;
      case 'hotel':
      case 'hostel':
        return Icons.hotel_outlined;
      case 'assignment':
      case 'exam':
        return Icons.assignment_outlined;
      case 'sports_soccer':
      case 'sports':
        return Icons.sports_soccer_outlined;
      case 'chat':
      case 'message':
        return Icons.chat_outlined;
      case 'people':
      case 'staff':
        return Icons.people_outline;
      case 'security':
      case 'biometric':
        return Icons.security_outlined;
      case 'settings':
      case 'config':
        return Icons.settings_outlined;
      default:
        return Icons.extension_outlined;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'core':
        return const Color(0xFF3B82F6); // Blue
      case 'academics':
        return const Color(0xFF8B5CF6); // Purple
      case 'finance':
        return const Color(0xFF10B981); // Green
      case 'transport':
        return const Color(0xFFEC4899); // Pink
      case 'hostel':
        return const Color(0xFFF59E0B); // Orange
      case 'resources':
        return const Color(0xFF06B6D4); // Cyan
      case 'hr':
        return const Color(0xFF14B8A6); // Teal
      default:
        return const Color(0xFF64748B); // Slate
    }
  }
}

// ============================================================
// DONUT CHART CUSTOM PAINTER FOR CATEGORIES USAGE
// ============================================================

class CategoryDonutPainter extends CustomPainter {
  final Map<String, int> data;
  final List<Color> colors;

  CategoryDonutPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.12;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final total = data.values.fold(0, (sum, val) => sum + val);
    if (total == 0) {
      paint.color = Colors.grey.withOpacity(0.2);
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    double startAngle = -3.14159 / 2; // Start from top
    int index = 0;

    data.forEach((key, val) {
      final sweepAngle = (val / total) * 2 * 3.14159;
      paint.color = colors[index % colors.length];
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
      index++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================
// DONUT CHART CUSTOM PAINTER FOR ASSIGNMENT SUMMARY
// ============================================================

class AssignmentSummaryDonutPainter extends CustomPainter {
  final int assigned;
  final int newlySelected;
  final int notSelected;
  final List<Color> colors;

  AssignmentSummaryDonutPainter({
    required this.assigned,
    required this.newlySelected,
    required this.notSelected,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.12;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final total = assigned + newlySelected + notSelected;
    if (total == 0) {
      paint.color = Colors.grey.withOpacity(0.2);
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    double startAngle = -3.14159 / 2; // Start from top

    // 1. Assigned (Green)
    if (assigned > 0) {
      final sweepAngle = (assigned / total) * 2 * 3.14159;
      paint.color = colors[0];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // 2. Newly Selected (Purple)
    if (newlySelected > 0) {
      final sweepAngle = (newlySelected / total) * 2 * 3.14159;
      paint.color = colors[1];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // 3. Not Selected (Gray)
    if (notSelected > 0) {
      final sweepAngle = (notSelected / total) * 2 * 3.14159;
      paint.color = colors[2];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
