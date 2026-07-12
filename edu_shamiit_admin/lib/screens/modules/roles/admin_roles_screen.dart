import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:intl/intl.dart';

class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});

  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  
  bool _isLoading = true;
  List<dynamic> _roles = [];
  List<String> _systemPermissions = [];
  Map<String, dynamic>? _selectedRole;
  
  // Modules data
  List<dynamic> _modules = [];
  bool _isLoadingModules = true;
  Map<String, dynamic>? _selectedModule; // Active selected module in Assign Permissions tab
  String _moduleSearchQuery = "";
  
  // Search & Filter state
  String _searchQuery = "";
  String _statusFilter = "All Status"; // "All Status", "Active", "Inactive"
  String _activeTab = "Roles"; // "Roles", "Role Hierarchy", "Assign Permissions"
  
  // Pagination
  int _currentPage = 1;
  final int _pageSize = 10;

  // In-memory permissions map for selected role in Assign Permissions tab
  // Key: "module_id:action" -> Value: "allow" / "deny" / "not_set"
  final Map<String, String> _rolePermissionsMap = {};

  // Standard CRUD & System actions for each module
  final List<Map<String, String>> _permissionActions = [
    {'action': 'create', 'label': 'Create', 'desc': 'Add new items or records'},
    {'action': 'read', 'label': 'Read', 'desc': 'View list and details records'},
    {'action': 'update', 'label': 'Update', 'desc': 'Modify existing records'},
    {'action': 'delete', 'label': 'Delete', 'desc': 'Permanently delete records'},
    {'action': 'export', 'label': 'Export', 'desc': 'Export module data to CSV/Excel'},
    {'action': 'import', 'label': 'Import', 'desc': 'Import records from files'},
    {'action': 'approve', 'label': 'Approve', 'desc': 'Approve or verify transactions'},
    {'action': 'activate_deactivate', 'label': 'Activate / Deactivate', 'desc': 'Activate or deactivate records'},
    {'action': 'view_audit', 'label': 'View Audit Logs', 'desc': 'View activity log for this module'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRoles();
    _fetchModules();
  }

  Future<void> _fetchRoles() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/schools/roles', useCache: false);
      if (res['success'] == true) {
        final rolesData = res['data'] as List<dynamic>? ?? [];
        final systemPerms = (res['system_permissions'] as List<dynamic>?)?.map((p) => p.toString()).toList() ?? [];
        
        setState(() {
          _roles = rolesData;
          _systemPermissions = systemPerms;
          
          if (_roles.isNotEmpty) {
            final storedRoleId = CacheService().get<String>('selected_role_id');
            if (storedRoleId != null) {
              final stillExists = _roles.firstWhere(
                (r) => r['id'] == storedRoleId,
                orElse: () => null,
              );
              _selectedRole = stillExists ?? _roles.first;
            } else {
              _selectedRole = _roles.first;
            }
            _loadRolePermissions();
          } else {
            _selectedRole = null;
          }
        });
      } else {
        _showErrorSnackBar(res['message'] ?? 'Failed to fetch roles');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchModules() async {
    setState(() {
      _isLoadingModules = true;
    });
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
          if (_modules.isNotEmpty && _selectedModule == null) {
            _selectedModule = _modules.first;
          }
        });
      }
    } catch (e) {
      print("Error fetching modules: $e");
    } finally {
      setState(() {
        _isLoadingModules = false;
      });
    }
  }

  void _loadRolePermissions() {
    _rolePermissionsMap.clear();
    if (_selectedRole != null) {
      final List<dynamic> draftPerms = _selectedRole!['draft_permissions'] ?? [];
      final List<dynamic> activePerms = _selectedRole!['permissions'] ?? [];
      final bool hasDraftModulePerms = draftPerms.any((p) => p.toString().contains(':'));
      final List<dynamic> perms = hasDraftModulePerms ? draftPerms : activePerms;

      for (final p in perms) {
        final str = p.toString();
        final parts = str.split(':');
        if (parts.length == 3) {
          _rolePermissionsMap['${parts[0]}:${parts[1]}'] = parts[2];
        } else {
          // Fallback mapping for standard flat strings (e.g. view_reports)
          _rolePermissionsMap[str] = 'allow';
        }
      }
    }
  }

  List<String> _buildPermissionsList() {
    final List<String> list = [];
    _rolePermissionsMap.forEach((key, effect) {
      if (effect == 'allow' || effect == 'deny') {
        if (key.contains(':')) {
          list.add('$key:$effect');
        } else {
          if (effect == 'allow') {
            list.add(key);
          }
        }
      }
    });
    return list;
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteRole(String roleId, String roleName) async {
    try {
      final res = await ApiService().delete('/admin/schools/roles/$roleId');
      if (res['success'] == true) {
        _showSuccessSnackBar('Role "$roleName" deleted successfully');
        _fetchRoles();
      } else {
        _showErrorSnackBar(res['message'] ?? 'Failed to delete role');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _savePermissions({required bool publish}) async {
    if (_selectedRole == null) return;
    final permsList = _buildPermissionsList();
    try {
      final Map<String, dynamic> body = {
        'draft_permissions': permsList,
      };
      if (publish) {
        body['permissions'] = permsList;
      }
      final res = await ApiService().put('/admin/schools/roles/${_selectedRole!['id']}', body);
      if (res['success'] == true) {
        _showSuccessSnackBar(
          publish
              ? 'Permissions for "${_selectedRole!['name']}" published successfully!'
              : 'Draft permissions for "${_selectedRole!['name']}" saved successfully.'
        );
        _fetchRoles();
      } else {
        _showErrorSnackBar(res['message'] ?? 'Failed to save permissions');
      }
    } catch (e) {
      _showErrorSnackBar('Network error: $e');
    }
  }

  bool _hasPendingPublish(Map<String, dynamic> role) {
    return role['has_pending_publish'] ?? false;
  }

  void _openRoleFormDialog([Map<String, dynamic>? role]) {
    final isEdit = role != null;
    final nameController = TextEditingController(text: role?['name'] ?? '');
    final codeController = TextEditingController(text: role?['code'] ?? '');
    final descController = TextEditingController(text: role?['description'] ?? '');
    String status = role?['status'] ?? 'Active';
    
    final List<dynamic> rolePermsRaw = role?['permissions'] ?? [];
    final List<String> selectedPermissions = List<String>.from(rolePermsRaw);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isBuiltIn = isEdit && !(role['is_custom'] ?? true);

            return Dialog(
              backgroundColor: const Color(0xFF111428),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_rounded : Icons.add_moderator_rounded,
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Edit Role Details' : 'Create New Role',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Role Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Role Name',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: nameController,
                                        enabled: !isBuiltIn,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g., Accountant',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 13,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF070913),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Role Code
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Role Code (System Identifier)',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: codeController,
                                        enabled: !isBuiltIn,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g., ROLE_ACCOUNTANT',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 13,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF070913),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Status & Type row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Status',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF070913),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: status,
                                            dropdownColor: const Color(0xFF111428),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: "Active", child: Text("Active")),
                                              DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDialogState(() {
                                                  status = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Role Type',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E2135).withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isBuiltIn ? "System Built-in Role" : "Custom User Role",
                                          style: TextStyle(
                                            color: isBuiltIn 
                                                ? const Color(0xFF6366F1)
                                                : const Color(0xFF3B82F6),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            const Text(
                              'Description',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter role details and responsibilities...',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF070913),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'System Permissions (${selectedPermissions.length} selected)',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedPermissions.clear();
                                          selectedPermissions.addAll(_systemPermissions);
                                        });
                                      },
                                      child: const Text('Select All', style: TextStyle(fontSize: 11)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setDialogState(() {
                                          selectedPermissions.clear();
                                        });
                                      },
                                      child: const Text('Clear All', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF070913),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _systemPermissions.map((permission) {
                                  final isSelected = selectedPermissions.contains(permission);
                                  return FilterChip(
                                    label: Text(
                                      permission.replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: const Color(0xFF6366F1),
                                    backgroundColor: const Color(0xFF111428),
                                    checkmarkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    onSelected: (selected) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedPermissions.add(permission);
                                        } else {
                                          selectedPermissions.remove(permission);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final code = codeController.text.trim();
                            final desc = descController.text.trim();
                            
                            if (name.isEmpty) {
                              _showErrorSnackBar('Role name cannot be empty');
                              return;
                            }
                            
                            Navigator.of(context).pop();
                            
                            try {
                              if (isEdit) {
                                final res = await ApiService().put('/admin/schools/roles/${role['id']}', {
                                  'name': name,
                                  'code': code.isEmpty ? null : code,
                                  'description': desc,
                                  'permissions': selectedPermissions,
                                  'status': status,
                                });
                                if (res['success'] == true) {
                                  _showSuccessSnackBar('Role "$name" updated successfully');
                                  _fetchRoles();
                                } else {
                                  _showErrorSnackBar(res['message'] ?? 'Failed to update role');
                                }
                              } else {
                                final res = await ApiService().post('/admin/schools/roles', {
                                  'name': name,
                                  'code': code.isEmpty ? null : code,
                                  'description': desc,
                                  'permissions': selectedPermissions,
                                  'status': status,
                                });
                                if (res['success'] == true) {
                                  _showSuccessSnackBar('Role "$name" created successfully');
                                  _fetchRoles();
                                } else {
                                  _showErrorSnackBar(res['message'] ?? 'Failed to create role');
                                }
                              }
                            } catch (e) {
                              _showErrorSnackBar('Error: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(isEdit ? 'Save Changes' : 'Create Role'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF070913),
      cardColor: const Color(0xFF101323),
      primaryColor: const Color(0xFF6366F1),
      dividerColor: Colors.white.withOpacity(0.06),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF070913),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final showSplitScreen = constraints.maxWidth > 800;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(constraints.maxWidth),
                      _buildMetricsRow(constraints.maxWidth),
                      const SizedBox(height: 16),
                      
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT COLUMN: CONTENT ACCORDING TO TABS (70% width)
                              Expanded(
                                flex: 7,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF101323),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildTabsRow(),
                                      Expanded(
                                        child: _buildMainContent(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // RIGHT COLUMN: SIDEBAR PANELS (30% width)
                              if (showSplitScreen && _selectedRole != null) ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: _buildRightSidebarSection(),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_activeTab) {
      case "Roles":
        return Column(
          children: [
            _buildFilterSection(),
            Expanded(child: _buildRolesTable()),
          ],
        );
      case "Role Hierarchy":
        return _buildRoleHierarchyTree();
      case "Assign Permissions":
        return _buildAssignPermissionsView();
      case "Drafted Permissions":
        return _buildDraftedPermissionsView();
      default:
        return const SizedBox();
    }
  }

  // Header Builder
  Widget _buildHeader(double screenWidth) {
    final showProfileText = screenWidth > 950;
    final showEmailText = screenWidth > 1150;
    final searchWidth = screenWidth < 1000 ? 150.0 : 220.0;
    final showHelpAndNotif = screenWidth > 850;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roles Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create and manage roles to control access and permissions across the system.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF101323),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.business, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 6),
                    Text(
                      'All Institutions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white60),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              
              Container(
                width: searchWidth,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF101323),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search roles...',
                    hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    prefixIcon: Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 14),
                  ),
                ),
              ),
              
              if (showHelpAndNotif) ...[
                const SizedBox(width: 12),
                Icon(Icons.help_outline_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 12),
                
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 18, color: Colors.white.withOpacity(0.6)),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: const Text(
                          '12',
                          style: TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  ],
                ),
              ],
              
              if (showProfileText) ...[
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Super Admin',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    if (showEmailText)
                      const Text(
                        'superadmin@schoolerp.com',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                  ],
                ),
              ],
              const SizedBox(width: 12),
              
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF6366F1),
                child: Text('SA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }

  // Metrics Row
  Widget _buildMetricsRow(double screenWidth) {
    final systemRoles = _roles.where((r) => r['is_custom'] == false).length;
    final customRoles = _roles.where((r) => r['is_custom'] == true).length;
    final usersCount = _roles.fold<int>(0, (sum, r) => sum + ((r['user_count'] as num?)?.toInt() ?? 0));
    final totalPermissionsAssigned = _roles.fold<int>(0, (sum, r) {
      final List<dynamic> perms = r['permissions'] ?? [];
      return sum + perms.length;
    });

    double cardWidth = (screenWidth - 96) / 5;
    if (cardWidth < 200) cardWidth = 200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMetricCardItem('Total Roles', '${systemRoles + customRoles}', 'Active roles in system', Icons.shield_outlined, const Color(0xFF818CF8), cardWidth),
            const SizedBox(width: 12),
            _buildMetricCardItem('System Roles', '$systemRoles', 'Default system roles', Icons.security_outlined, const Color(0xFF38BDF8), cardWidth),
            const SizedBox(width: 12),
            _buildMetricCardItem('Custom Roles', '$customRoles', 'Custom created roles', Icons.group_outlined, const Color(0xFF60A5FA), cardWidth),
            const SizedBox(width: 12),
            _buildMetricCardItem('Users Assigned', '$usersCount', 'Users with roles', Icons.people_outline, const Color(0xFF34D399), cardWidth),
            const SizedBox(width: 12),
            _buildMetricCardItem('Permissions', '$totalPermissionsAssigned', 'Total assigned permissions', Icons.key_outlined, const Color(0xFFFBBF24), cardWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCardItem(String title, String value, String subtitle, IconData icon, Color accentColor, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101323),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isActive = _activeTab == tabName;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabName;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF6366F1) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }

  // Tabs Row
  Widget _buildTabsRow() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          _buildTabButton("Roles"),
          const SizedBox(width: 8),
          _buildTabButton("Role Hierarchy"),
          if (_selectedRole != null) ...[
            const SizedBox(width: 8),
            _buildTabButton("Assign Permissions"),
            const SizedBox(width: 8),
            _buildTabButton("Drafted Permissions"),
          ],
        ],
      ),
    );
  }

  // Filters Row
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 260,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF070913),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search roles...',
                    hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF475569)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(bottom: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF070913),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: const Color(0xFF101323),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: "All Status", child: Text("All Status")),
                      DropdownMenuItem(value: "Active", child: Text("Active")),
                      DropdownMenuItem(value: "Inactive", child: Text("Inactive")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune, size: 14, color: Color(0xFF64748B)),
            label: const Text('Filters', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.06)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          )
        ],
      ),
    );
  }

  // Roles Table
  Widget _buildRolesTable() {
    final filteredRoles = _roles.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();
      final status = (r['status'] ?? 'Active').toString().toLowerCase();
      
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || 
                            desc.contains(_searchQuery.toLowerCase()) ||
                            code.contains(_searchQuery.toLowerCase());
                            
      final matchesStatus = _statusFilter == "All Status" || 
                            status == _statusFilter.toLowerCase();
                            
      return matchesSearch && matchesStatus;
    }).toList();

    final totalCount = filteredRoles.length;
    final totalPages = (totalCount / _pageSize).ceil();
    final startIdx = (_currentPage - 1) * _pageSize;
    final endIdx = startIdx + _pageSize > totalCount ? totalCount : startIdx + _pageSize;
    final paginatedRoles = totalCount == 0 ? [] : filteredRoles.sublist(startIdx, endIdx);

    if (paginatedRoles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: Color(0xFF475569)),
            const SizedBox(height: 12),
            Text(
              'No roles match your search filters.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF070913).withOpacity(0.5),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('ROLE NAME', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 1, child: Text('TYPE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 1, child: Text('USERS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 1, child: Text('PERMISSIONS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 1, child: Text('CREATED ON', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              Expanded(flex: 1, child: Text('STATUS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
              const SizedBox(width: 100, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
            ],
          ),
        ),
        
        Expanded(
          child: Scrollbar(
            controller: _leftScrollController,
            child: ListView.builder(
              controller: _leftScrollController,
              itemCount: paginatedRoles.length,
              itemBuilder: (context, idx) {
                final role = paginatedRoles[idx];
                final id = role['id'];
                final name = (role['name'] ?? '').toString();
                final description = (role['description'] ?? 'No description provided').toString();
                final isCustom = role['is_custom'] ?? true;
                final userCount = role['user_count'] ?? 0;
                final perms = (role['permissions'] as List<dynamic>?) ?? [];
                final createdAtStr = role['created_at'] != null 
                    ? DateFormat('MMM dd, YYYY').format(DateTime.parse(role['created_at'].toString()))
                    : 'N/A';
                final status = role['status'] ?? 'Active';
                
                final isSelected = _selectedRole != null && _selectedRole!['id'] == id;
                
                final formattedName = name.split('_').map((word) {
                  if (word.isEmpty) return '';
                  return word[0].toUpperCase() + word.substring(1).toLowerCase();
                }).join(' ');
                
                Color avatarColor = const Color(0xFF6366F1);
                if (name == 'super_admin') avatarColor = const Color(0xFF818CF8);
                else if (name == 'admin') avatarColor = const Color(0xFF38BDF8);
                else if (name == 'director') avatarColor = const Color(0xFF60A5FA);
                else if (isCustom) avatarColor = const Color(0xFFC084FC);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedRole = role;
                      _loadRolePermissions();
                      CacheService().set('selected_role_id', role['id']);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6366F1).withOpacity(0.04) : null,
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
                        left: BorderSide(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: avatarColor.withOpacity(0.1),
                                child: Icon(
                                  name == 'super_admin' ? Icons.security_rounded : Icons.person_rounded, 
                                  size: 14, 
                                  color: avatarColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          formattedName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (_hasPendingPublish(role)) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2), width: 0.5),
                                            ),
                                            child: const Text(
                                              'DRAFT',
                                              style: TextStyle(
                                                color: Color(0xFFF59E0B),
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCustom
                                    ? const Color(0xFF3B82F6).withOpacity(0.1)
                                    : const Color(0xFF6366F1).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCustom ? 'Custom' : 'System',
                                style: TextStyle(
                                  color: isCustom ? const Color(0xFF3082F6) : const Color(0xFF818CF8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        Expanded(
                          flex: 1,
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 12, color: Colors.white.withOpacity(0.4)),
                              const SizedBox(width: 4),
                              Text('$userCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${role['permissions_count'] ?? 0}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        
                        Expanded(
                          flex: 1,
                          child: Text(createdAtStr, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                        
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: status == "Active"
                                    ? const Color(0xFF064E3B)
                                    : const Color(0xFF7F1D1D),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: status == "Active" ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.vpn_key_outlined, size: 16, color: Color(0xFF818CF8)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Assign Permissions',
                                onPressed: () {
                                  setState(() {
                                    _selectedRole = role;
                                    _loadRolePermissions();
                                    _activeTab = "Assign Permissions";
                                    CacheService().set('selected_role_id', role['id']);
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white60),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openRoleFormDialog(role),
                              ),
                              const SizedBox(width: 8),
                              
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white60),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: const Color(0xFF101323),
                                onSelected: (action) {
                                  if (action == 'delete') {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          backgroundColor: const Color(0xFF111428),
                                          title: const Text('Delete Role?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                          content: Text('Are you sure you want to delete custom role "$name"? this action is permanent.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                _deleteRole(id, name);
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  } else if (action == 'toggle_status') {
                                    final newStatus = status == 'Active' ? 'Inactive' : 'Active';
                                    ApiService().put('/admin/schools/roles/$id', {'status': newStatus}).then((res) {
                                      if (res['success'] == true) {
                                        _showSuccessSnackBar('Role "$name" status set to $newStatus');
                                        _fetchRoles();
                                      } else {
                                        _showErrorSnackBar(res['message'] ?? 'Failed to update status');
                                      }
                                    });
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle_status',
                                    child: Row(
                                      children: [
                                        Icon(status == 'Active' ? Icons.block : Icons.check_circle_outline, size: 14),
                                        const SizedBox(width: 8),
                                        Text(status == 'Active' ? 'Deactivate Role' : 'Activate Role', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  if (isCustom)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                                          const SizedBox(width: 8),
                                          Text('Delete Role', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                                        ],
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
                );
              },
            ),
          ),
        ),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${totalCount == 0 ? 0 : startIdx + 1} to $endIdx of $totalCount roles',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 18),
                    onPressed: _currentPage > 1 ? () {
                      setState(() {
                        _currentPage--;
                      });
                    } : null,
                  ),
                  
                  for (int i = 1; i <= totalPages; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPage = i;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _currentPage == i ? const Color(0xFF6366F1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            color: _currentPage == i ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: _currentPage < totalPages ? () {
                      setState(() {
                        _currentPage++;
                      });
                    } : null,
                  ),
                  
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070913),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: const Row(
                      children: [
                        Text('10 / page', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 12, color: Colors.white60),
                      ],
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

  // Hierarchy Tree
  Widget _buildRoleHierarchyTree() {
    return SingleChildScrollView(
      controller: _leftScrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildTreeNodeItem("Super Admin", "Full system access with all permissions", const Color(0xFF6366F1)),
          _buildVerticalConnector(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTreeNodeItem("Institute Admin", "Manage institute settings and data", const Color(0xFF10B981)),
              const SizedBox(width: 48),
              _buildTreeNodeItem("Academic Admin", "Manage academics and curriculum", const Color(0xFF3B82F6)),
            ],
          ),
          _buildVerticalConnector(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTreeNodeItem("Teacher", "Manage classes and students", const Color(0xFF8B5CF6)),
              const SizedBox(width: 48),
              _buildTreeNodeItem("Finance Staff", "Manage finance and accounts", const Color(0xFFF59E0B)),
            ],
          ),
          _buildVerticalConnector(),
          _buildTreeNodeItem("Student", "Access own learning and profile", const Color(0xFF64748B)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTreeNodeItem(String name, String desc, Color highlightColor) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070913),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlightColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: highlightColor.withOpacity(0.04), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: highlightColor.withOpacity(0.1),
                child: Icon(Icons.shield_outlined, color: highlightColor, size: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalConnector() {
    return Column(
      children: [
        Container(width: 1.5, height: 24, color: Colors.white10),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white24),
      ],
    );
  }

  // =========================================================================
  // ASSIGN MODULES & PERMISSIONS VIEW (Matches second screenshot layout)
  // =========================================================================
  Widget _buildAssignPermissionsView() {
    if (_selectedRole == null) {
      return const Center(child: Text("Please select a role first", style: TextStyle(color: Colors.white70)));
    }

    final filteredModules = _modules.where((m) {
      final name = (m['name'] ?? '').toString().toLowerCase();
      final desc = (m['description'] ?? '').toString().toLowerCase();
      return name.contains(_moduleSearchQuery.toLowerCase()) || 
             desc.contains(_moduleSearchQuery.toLowerCase());
    }).toList();

    final formattedRoleName = (_selectedRole!['name'] ?? '').toString().split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    final totalSystemPerms = _modules.length * 9;
    final totalAllowed = _rolePermissionsMap.entries.where((e) => e.key.contains(':') && e.value == 'allow').length;

    return Column(
      children: [
        // Active role banner showing clearly which role is being edited
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            border: Border(bottom: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.2))),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFF818CF8), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Configure Access Level For Role:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Text(
                formattedRoleName,
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              const SizedBox(width: 6),
              Text(
                '(${_selectedRole!['code'] ?? ''})',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  '$totalAllowed / $totalSystemPerms Configured',
                  style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        
        // Inner Content (Modules list on left, Permissions table on right)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MODULES TREE COLUMN
              Container(
                width: 250,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
                child: Column(
                  children: [
                    // Search modules input box
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070913),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          onChanged: (val) {
                            setState(() {
                              _moduleSearchQuery = val;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search modules...',
                            hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 11),
                            prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF475569)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 14),
                          ),
                        ),
                      ),
                    ),
                    
                    // Select All Modules checkbox
                    Material(
                      color: Colors.transparent,
                      child: CheckboxListTile(
                        value: _modules.isNotEmpty && _modules.every((m) {
                          final String modId = m['id'];
                          return _permissionActions.any((actionMap) {
                            final action = actionMap['action']!;
                            return _rolePermissionsMap['$modId:$action'] == 'allow';
                          });
                        }),
                        title: const Text('Select All Modules', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: const Color(0xFF6366F1),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              // Turn Allow on for all modules
                              for (final m in _modules) {
                                final String modId = m['id'];
                                for (final actionMap in _permissionActions) {
                                  final action = actionMap['action']!;
                                  _rolePermissionsMap['$modId:$action'] = 'allow';
                                }
                              }
                            } else {
                              // Clear all permissions map
                              _rolePermissionsMap.clear();
                            }
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    
                    // Tree list
                    Expanded(
                      child: _isLoadingModules
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                          : ListView.builder(
                              itemCount: filteredModules.length,
                              itemBuilder: (context, idx) {
                                final m = filteredModules[idx];
                                final String modId = m['id'];
                                final String modName = m['name'] ?? '';
                                final isSelected = _selectedModule != null && _selectedModule!['id'] == modId;
                                
                                // Check if any permission in this module is set (for the check icon indicator)
                                final hasAnyPerm = _permissionActions.any((actionMap) {
                                  final action = actionMap['action']!;
                                  final val = _rolePermissionsMap['$modId:$action'];
                                  return val == 'allow' || val == 'deny';
                                });
                                final allowedCount = _permissionActions.where((actionMap) {
                                  final action = actionMap['action']!;
                                  final val = _rolePermissionsMap['$modId:$action'];
                                  return val == 'allow';
                                }).length;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedModule = m;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF6366F1).withOpacity(0.08) : null,
                                      border: Border(
                                        left: BorderSide(
                                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                                          width: 3.5,
                                        ),
                                        bottom: BorderSide(color: Colors.white.withOpacity(0.02)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Custom checkbox indicator - clickable to toggle all
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedModule = m;
                                              if (hasAnyPerm) {
                                                // Clear all
                                                for (final actionMap in _permissionActions) {
                                                  final action = actionMap['action']!;
                                                  _rolePermissionsMap.remove('$modId:$action');
                                                }
                                              } else {
                                                // Allow all
                                                for (final actionMap in _permissionActions) {
                                                  final action = actionMap['action']!;
                                                  _rolePermissionsMap['$modId:$action'] = 'allow';
                                                }
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: Icon(
                                              hasAnyPerm ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                              size: 16,
                                              color: hasAnyPerm ? const Color(0xFF10B981) : Colors.white30,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.extension_outlined,
                                          size: 14,
                                          color: isSelected ? const Color(0xFF818CF8) : (hasAnyPerm ? const Color(0xFF10B981) : Colors.white38),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            modName,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : (hasAnyPerm ? const Color(0xFF34D399) : Colors.white70),
                                              fontSize: 12,
                                              fontWeight: isSelected || hasAnyPerm ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (allowedCount > 0) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$allowedCount Configured',
                                              style: const TextStyle(
                                                color: Color(0xFF818CF8),
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        const Icon(Icons.chevron_right, size: 14, color: Colors.white24),
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
              
              // MIDDLE COLUMN: PERMISSIONS CONFIG TABLE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Module info banner
                    if (_selectedModule != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101323),
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _selectedModule!['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '9 Permissions',
                                    style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configure permissions for the selected module',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    
                    // Table headers
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070913).withOpacity(0.3),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Permission', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 5, child: Text('Description', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Allow', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Deny', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Not Set', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    
                    // Table rows
                    Expanded(
                      child: _selectedModule == null
                          ? const Center(child: Text("Select a module to view permissions", style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: _permissionActions.length,
                              itemBuilder: (context, rIdx) {
                                final row = _permissionActions[rIdx];
                                final action = row['action']!;
                                final label = row['label']!;
                                final desc = row['desc']!;
                                final modId = _selectedModule!['id'] as String;
                                
                                final currentEffect = _rolePermissionsMap['$modId:$action'] ?? 'not_set';

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      Expanded(
                                        flex: 5,
                                        child: Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                      ),
                                      
                                      // Allow radio
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rolePermissionsMap['$modId:$action'] = 'allow';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: currentEffect == 'allow' ? const Color(0xFF10B981) : Colors.white30,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 4,
                                                backgroundColor: currentEffect == 'allow' ? const Color(0xFF10B981) : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Deny radio
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rolePermissionsMap['$modId:$action'] = 'deny';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: currentEffect == 'deny' ? const Color(0xFFEF4444) : Colors.white30,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 4,
                                                backgroundColor: currentEffect == 'deny' ? const Color(0xFFEF4444) : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      // Not Set radio
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rolePermissionsMap.remove('$modId:$action');
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: currentEffect == 'not_set' ? const Color(0xFFF59E0B) : Colors.white30,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: CircleAvatar(
                                                radius: 4,
                                                backgroundColor: currentEffect == 'not_set' ? const Color(0xFFF59E0B) : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                        ),
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
            ],
          ),
        ),
        
        // FOOTER ACTION ROW
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101323),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _activeTab = "Roles";
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 14),
                label: const Text('Back', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Row(
                children: [
                   OutlinedButton(
                    onPressed: () => _savePermissions(publish: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save as Draft', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await _savePermissions(publish: true);
                      setState(() {
                        _activeTab = "Roles";
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Review & Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(String index, String title, bool isActive) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isActive ? const Color(0xFF6366F1) : const Color(0xFF1F2937),
          child: Text(index, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 1.5,
        color: Colors.white10,
      ),
    );
  }

  // Right sidebar details section
  Widget _buildRightSidebarSection() {
    if (_selectedRole == null) return const SizedBox();
    
    final name = (_selectedRole!['name'] ?? '').toString();
    final code = (_selectedRole!['code'] ?? 'ROLE_${name.toUpperCase()}').toString();
    final description = (_selectedRole!['description'] ?? 'No description provided').toString();
    final isCustom = _selectedRole!['is_custom'] ?? true;
    final userCount = _selectedRole!['user_count'] ?? 0;
    
    final createdAtStr = _selectedRole!['created_at'] != null 
        ? DateFormat('MMM dd, YYYY hh:mm a').format(DateTime.parse(_selectedRole!['created_at'].toString()))
        : 'N/A';
    final updatedAtStr = _selectedRole!['updated_at'] != null 
        ? DateFormat('MMM dd, YYYY hh:mm a').format(DateTime.parse(_selectedRole!['updated_at'].toString()))
        : 'N/A';

    final formattedName = name.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    // Calculate active published counts strictly from active permissions
    final totalSystemPerms = _modules.length * 9;
    final List<dynamic> activePerms = _selectedRole!['permissions'] ?? [];
    
    final activeAllowedCount = activePerms.where((p) {
      final str = p.toString();
      final parts = str.split(':');
      return parts.length == 3 && parts[2] == 'allow';
    }).length;
    
    final activeDeniedCount = activePerms.where((p) {
      final str = p.toString();
      final parts = str.split(':');
      return parts.length == 3 && parts[2] == 'deny';
    }).length;
    
    final activeNotSetCount = totalSystemPerms - activeAllowedCount - activeDeniedCount;
    final activeAllowedPercent = totalSystemPerms == 0 ? 0.0 : (activeAllowedCount / totalSystemPerms);

    final activeModulesSelectedSet = <String>{};
    for (final p in activePerms) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3 && (parts[2] == 'allow' || parts[2] == 'deny')) {
        activeModulesSelectedSet.add(parts[0]);
      }
    }
    final activeModulesSelectedCount = activeModulesSelectedSet.length;

    return Scrollbar(
      controller: _rightScrollController,
      child: SingleChildScrollView(
        controller: _rightScrollController,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _openRoleFormDialog(),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Create New Role',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (_hasPendingPublish(_selectedRole!)) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pending Publish',
                            style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This role has draft changes that are not yet active in the system.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final res = await ApiService().post('/admin/schools/roles/${_selectedRole!['id']}/publish', {});
                            if (res['success'] == true) {
                              _showSuccessSnackBar('Permissions published successfully!');
                              _fetchRoles();
                            } else {
                              _showErrorSnackBar(res['message'] ?? 'Failed to publish permissions');
                            }
                          } catch (e) {
                            _showErrorSnackBar('Network error: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Publish Draft Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // PANEL 1: Role Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101323),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Role Details',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.shield_outlined, color: Color(0xFF6366F1), size: 18),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formattedName,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCustom ? 'Custom Role' : 'System Role',
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name == 'super_admin' ? 'Full system access with all permissions' : 'Manage $name system configurations and access',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDetailRowItem('Role Name', formattedName),
                  _buildDetailRowItem('Role Code', code),
                  _buildDetailRowItem('Description', description),
                  _buildDetailRowItem('Users Assigned', '$userCount'),
                  if (_selectedRole!['has_pending_publish'] == true) ...[
                    _buildDetailRowItem('Active Permissions', '$activeAllowedCount'),
                    _buildDetailRowItem('Draft Permissions', '${_selectedRole!['draft_permissions_count'] ?? 0}'),
                  ] else ...[
                    _buildDetailRowItem('Permissions', '$activeAllowedCount'),
                  ],
                  _buildDetailRowItem('Created On', createdAtStr),
                  _buildDetailRowItem('Last Updated', updatedAtStr),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openRoleFormDialog(_selectedRole),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit Role', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showSuccessSnackBar("Showing list of users assigned to $formattedName...");
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF818CF8),
                            side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('View Users ($userCount)', style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // PANEL 2: Permissions Overview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101323),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Permissions Overview',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  
                  Center(
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: activeAllowedPercent,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFF1F2937),
                            color: const Color(0xFF10B981),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(activeAllowedPercent * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const Text(
                                'Granted',
                                style: TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildLegendDotRow('Granted', '$activeAllowedCount (${(activeAllowedPercent * 100).toInt()}%)', const Color(0xFF10B981)),
                  _buildLegendDotRow('Denied', '$activeDeniedCount (${totalSystemPerms == 0 ? 0 : (activeDeniedCount / totalSystemPerms * 100).toInt()}%)', const Color(0xFFEF4444)),
                  _buildLegendDotRow('Not Set', '$activeNotSetCount (${totalSystemPerms == 0 ? 0 : (activeNotSetCount / totalSystemPerms * 100).toInt()}%)', const Color(0xFF64748B)),
                  
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  
                  _buildLegendDotRow('Modules Selected', '$activeModulesSelectedCount/${_modules.length}', const Color(0xFF6366F1)),
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _activeTab = "Assign Permissions";
                        });
                      },
                      icon: const Icon(Icons.settings_outlined, size: 14),
                      label: const Text('Manage Permissions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF818CF8),
                        side: BorderSide(color: Colors.white.withOpacity(0.06)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // PANEL 3: Role Hierarchy
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101323),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Role Hierarchy',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Column(
                    children: [
                      _buildMiniNode("Super Admin", const Color(0xFF6366F1)),
                      _buildMiniConnector(),
                      _buildMiniNode(formattedName, const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _activeTab = "Role Hierarchy";
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white60,
                        side: BorderSide(color: Colors.white.withOpacity(0.06)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View Full Hierarchy →', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRowItem(String key, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDotRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMiniNode(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF070913),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: color, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniConnector() {
    return Container(
      width: 1.5,
      height: 16,
      color: Colors.white10,
    );
  }

  // =========================================================================
  // DRAFTED PERMISSIONS COMPARISON VIEW
  // =========================================================================
  Widget _buildDraftedPermissionsView() {
    if (_selectedRole == null) {
      return const Center(child: Text("Please select a role first", style: TextStyle(color: Colors.white70)));
    }

    final filteredModules = _modules.where((m) {
      final String modId = m['id'];
      if (!_hasModuleDraftChanges(modId)) return false;

      final name = (m['name'] ?? '').toString().toLowerCase();
      final desc = (m['description'] ?? '').toString().toLowerCase();
      return name.contains(_moduleSearchQuery.toLowerCase()) || 
             desc.contains(_moduleSearchQuery.toLowerCase());
    }).toList();

    final name = (_selectedRole!['name'] ?? '').toString();
    final code = (_selectedRole!['code'] ?? 'ROLE_${name.toUpperCase()}').toString();
    final formattedRoleName = name.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    final totalSystemPerms = _modules.length * 9;
    int totalDraftChanges = 0;
    final List<dynamic> perms = _selectedRole!['permissions'] ?? [];
    final List<dynamic> draft = _selectedRole!['draft_permissions'] ?? [];
    
    final Map<String, String> activeMap = {};
    for (final p in perms) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3) {
        activeMap['${parts[0]}:${parts[1]}'] = parts[2];
      }
    }
    
    final Map<String, String> draftMap = {};
    for (final p in draft) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3) {
        draftMap['${parts[0]}:${parts[1]}'] = parts[2];
      }
    }
    
    for (final m in _modules) {
      final String modId = m['id'];
      for (final actionMap in _permissionActions) {
        final action = actionMap['action']!;
        final activeVal = activeMap['$modId:$action'] ?? 'not_set';
        final draftVal = draftMap['$modId:$action'] ?? 'not_set';
        if (activeVal != draftVal) {
          totalDraftChanges++;
        }
      }
    }

    if (filteredModules.isEmpty) {
      return Column(
        children: [
          // Active role banner showing clearly which role is being edited
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              border: Border(bottom: BorderSide(color: const Color(0xFF10B981).withOpacity(0.2))),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 8),
                Text(
                  'All permissions are fully published for: ',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
                Text(
                  '$formattedRoleName ($code)',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all_rounded, size: 48, color: const Color(0xFF10B981).withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'No Pending Drafts Found',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All permissions are in sync with the live system.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final activeSelectedModule = _selectedModule != null && filteredModules.any((m) => m['id'] == _selectedModule!['id'])
        ? _selectedModule
        : (filteredModules.isNotEmpty ? filteredModules.first : null);

    return Column(
      children: [
        // Active role banner showing clearly which role is being edited
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withOpacity(0.08),
            border: Border(bottom: BorderSide(color: const Color(0xFFF59E0B).withOpacity(0.2))),
          ),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: Color(0xFFF59E0B), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Reviewing Draft Permissions For:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Text(
                formattedRoleName,
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              const SizedBox(width: 6),
              Text(
                '($code)',
                style: TextStyle(color: Colors.white30, fontSize: 11),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  '$totalDraftChanges Pending Changes',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Inner Content
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MODULES LIST COLUMN
              Container(
                width: 250,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
                child: Column(
                  children: [
                    // Search modules input box
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070913),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          onChanged: (val) {
                            setState(() {
                              _moduleSearchQuery = val;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Search modules...',
                            hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 11),
                            prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF475569)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 14),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    
                    // List
                    Expanded(
                      child: _isLoadingModules
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                          : ListView.builder(
                              itemCount: filteredModules.length,
                              itemBuilder: (context, idx) {
                                final m = filteredModules[idx];
                                final String modId = m['id'];
                                final String modName = m['name'] ?? '';
                                final isSelected = activeSelectedModule != null && activeSelectedModule['id'] == modId;
                                
                                // Check if this module has differences
                                final hasDraftChange = _hasModuleDraftChanges(modId);

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedModule = m;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF6366F1).withOpacity(0.08) : null,
                                      border: Border(
                                        left: BorderSide(
                                          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                                          width: 3.5,
                                        ),
                                        bottom: BorderSide(color: Colors.white.withOpacity(0.02)),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.extension_outlined,
                                          size: 14,
                                          color: isSelected ? const Color(0xFF818CF8) : (hasDraftChange ? const Color(0xFFF59E0B) : Colors.white38),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            modName,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : (hasDraftChange ? const Color(0xFFF59E0B) : Colors.white70),
                                              fontSize: 12,
                                              fontWeight: isSelected || hasDraftChange ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        if (hasDraftChange) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'PENDING',
                                              style: TextStyle(
                                                color: Color(0xFFF59E0B),
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        const Icon(Icons.chevron_right, size: 14, color: Colors.white24),
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
              
              // MIDDLE COLUMN: PERMISSIONS CONFIG TABLE
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Module info banner
                    if (activeSelectedModule != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101323),
                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  activeSelectedModule['name'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Draft Comparison',
                                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compare active (published) permissions vs draft (unpublished) changes',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    
                    // Table headers
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070913).withOpacity(0.3),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Permission', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('Active (Published)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('Draft (Unpublished)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    
                    // Table rows
                    Expanded(
                      child: activeSelectedModule == null
                          ? const Center(child: Text("Select a module to view comparisons", style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: _permissionActions.length,
                              itemBuilder: (context, rIdx) {
                                final row = _permissionActions[rIdx];
                                final action = row['action']!;
                                final label = row['label']!;
                                final modId = activeSelectedModule['id'] as String;
                                
                                final activeEffect = _getPermissionEffect(_selectedRole!['permissions'] ?? [], modId, action);
                                final draftEffect = _getPermissionEffect(_selectedRole!['draft_permissions'] ?? [], modId, action);
                                final isDifferent = activeEffect != draftEffect;

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      
                                      // Active Effect
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: _buildEffectBadge(activeEffect),
                                        ),
                                      ),
                                      
                                      // Draft Effect
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: _buildEffectBadge(draftEffect, isDraft: true),
                                        ),
                                      ),
                                      
                                      // Status
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDifferent
                                                  ? const Color(0xFFF59E0B).withOpacity(0.12)
                                                  : Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isDifferent ? 'CHANGED' : 'SAME',
                                              style: TextStyle(
                                                color: isDifferent ? const Color(0xFFF59E0B) : Colors.white30,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
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
            ],
          ),
        ),
        
        // FOOTER ACTION ROW
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101323),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _activeTab = "Roles";
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 14),
                label: const Text('Back', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      // Discard Draft: reset draft_permissions to permissions
                      try {
                        final res = await ApiService().put('/admin/schools/roles/${_selectedRole!['id']}', {
                          'draft_permissions': _selectedRole!['permissions'] ?? [],
                        });
                        if (res['success'] == true) {
                          _showSuccessSnackBar('Draft permissions discarded.');
                          _fetchRoles();
                        } else {
                          _showErrorSnackBar(res['message'] ?? 'Failed to discard draft');
                        }
                      } catch (e) {
                        _showErrorSnackBar('Network error: $e');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Discard Draft', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final res = await ApiService().post('/admin/schools/roles/${_selectedRole!['id']}/publish', {});
                        if (res['success'] == true) {
                          _showSuccessSnackBar('Permissions published successfully!');
                          _fetchRoles();
                          setState(() {
                            _activeTab = "Roles";
                          });
                        } else {
                          _showErrorSnackBar(res['message'] ?? 'Failed to publish permissions');
                        }
                      } catch (e) {
                        _showErrorSnackBar('Network error: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Publish Changes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasModuleDraftChanges(String modId) {
    if (_selectedRole == null) return false;
    if (!_hasPendingPublish(_selectedRole!)) return false;
    final List<dynamic> perms = _selectedRole!['permissions'] ?? [];
    final List<dynamic> draft = _selectedRole!['draft_permissions'] ?? [];
    if (draft.isEmpty) return false;
    
    final Map<String, String> activeMap = {};
    for (final p in perms) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3 && parts[0] == modId) {
        activeMap[parts[1]] = parts[2];
      }
    }
    
    final Map<String, String> draftMap = {};
    for (final p in draft) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3 && parts[0] == modId) {
        draftMap[parts[1]] = parts[2];
      }
    }
    
    for (final actionMap in _permissionActions) {
      final action = actionMap['action']!;
      final actVal = activeMap[action] ?? 'not_set';
      final dftVal = draftMap[action] ?? 'not_set';
      if (actVal != dftVal) return true;
    }
    return false;
  }

  String _getPermissionEffect(List<dynamic> permissionsList, String modId, String action) {
    for (final p in permissionsList) {
      final str = p.toString();
      final parts = str.split(':');
      if (parts.length == 3 && parts[0] == modId && parts[1] == action) {
        return parts[2];
      }
    }
    return 'not_set';
  }

  Widget _buildEffectBadge(String effect, {bool isDraft = false}) {
    Color badgeColor = const Color(0xFF64748B);
    String label = 'NOT SET';
    
    if (effect == 'allow') {
      badgeColor = const Color(0xFF10B981);
      label = 'ALLOW';
    } else if (effect == 'deny') {
      badgeColor = const Color(0xFFEF4444);
      label = 'DENY';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
