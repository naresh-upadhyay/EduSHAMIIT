import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/widgets/azure_grid.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _schools = [];
  bool _loadingUsers = true;
  bool _loadingSchools = true;

  // Role labels map for display
  static const Map<String, String> _roleLabels = {
    'super_admin': 'Super Admin',
    'admin': 'School Admin',
    'teacher': 'Teacher',
    'student': 'Student',
    'parent': 'Parent',
    'student_admin': 'Student Admin',
    'teacher_admin': 'Teacher Admin',
    'director': 'Director',
    'principal': 'Principal',
    'finance': 'Finance Staff',
    'hr': 'HR Manager',
    'transport': 'Transport Mgr',
    'library': 'Librarian',
    'security': 'Security Head',
    'sports': 'Sports Coach',
    'support': 'Support Staff',
    'driver': 'Bus Driver',
    'hostel': 'Hostel Warden',
    'exam_ctrl': 'Exam Controller',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchSchools();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
    });
    try {
      final res = await ApiService().get('/auth/users', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res['data']);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load users: $e', isError: true);
    } finally {
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  Future<void> _fetchSchools() async {
    setState(() {
      _loadingSchools = true;
    });
    try {
      final res = await ApiService().get('/admin/schools', useCache: false);
      if (res['success'] == true && res['data'] != null && res['data']['schools'] != null) {
        setState(() {
          _schools = List<Map<String, dynamic>>.from(res['data']['schools']);
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load schools: $e', isError: true);
    } finally {
      setState(() {
        _loadingSchools = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Color mappings for roles
  Color _getRoleColor(String role) {
    role = role.toLowerCase();
    if (role == 'super_admin') return const Color(0xFF8B5CF6); // purple
    if (role == 'admin' || role.endsWith('_admin')) return const Color(0xFF3B82F6); // blue
    if (role == 'teacher') return const Color(0xFF0D9488); // teal
    if (role == 'student') return const Color(0xFF10B981); // green
    if (role == 'parent') return const Color(0xFFF59E0B); // orange
    return const Color(0xFF64748B); // slate
  }

  // ─── CSV EXPORT ────────────────────────────────────────────────────
  void _exportUsersToCSV(List<Map<String, dynamic>> usersToExport) {
    if (usersToExport.isEmpty) {
      _showSnackBar('No users to export', isError: true);
      return;
    }
    
    final StringBuffer csv = StringBuffer();
    // Headers
    csv.writeln('User ID,Full Name,Email,Phone,Role,School,Class,Status');
    
    for (final user in usersToExport) {
      final userId = user['user_id'] ?? '';
      final name = user['full_name'] ?? '';
      final email = user['email'] ?? '';
      final phone = user['phone'] ?? '';
      final role = _roleLabels[user['role']] ?? user['role'] ?? '';
      final school = user['school_name'] ?? 'System-wide';
      final className = user['class'] ?? '';
      final isSuspended = user['school_status'] == 'suspended';
      final status = isSuspended ? 'Suspended' : 'Active';
      
      String escapeCsv(String val) {
        if (val.contains(',') || val.contains('"') || val.contains('\n')) {
          return '"${val.replaceAll('"', '""')}"';
        }
        return val;
      }
      
      csv.writeln([
        escapeCsv(userId),
        escapeCsv(name),
        escapeCsv(email),
        escapeCsv(phone),
        escapeCsv(role),
        escapeCsv(school),
        escapeCsv(className),
        escapeCsv(status)
      ].join(','));
    }
    
    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "exported_users.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
    _showSnackBar('Exported ${usersToExport.length} users successfully');
  }

  // ─── CSV TEMPLATE DOWNLOAD ─────────────────────────────────────────
  void _downloadCSVTemplate() {
    final StringBuffer csv = StringBuffer();
    csv.writeln('Name,Email,Phone,Password,Class Name (Optional)');
    csv.writeln('John Doe,john.doe@example.com,9876543210,Password123,10A');
    csv.writeln('Jane Smith,jane.smith@example.com,8765432109,Password123,');

    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "user_import_template.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
    _showSnackBar('CSV Import Template downloaded');
  }

  // Helper for CSV line parsing
  List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  // CSV parsing engine - FIXED prioritised header checking
  List<Map<String, String>> _parseCSV(String csvText) {
    final List<Map<String, String>> parsedUsers = [];
    final List<String> lines = csvText.split(RegExp(r'\r?\n'));
    if (lines.isEmpty || lines[0].trim().isEmpty) return [];

    // Parse header
    final List<String> headers = _splitCsvLine(lines[0]);
    if (headers.length < 3) return []; // Require Name, Email, Password at least

    // Map headers to standard fields (PRIORITISED matches to prevent Class Name from matching full_name)
    final Map<int, String> headerMap = {};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].trim().toLowerCase();
      if (h.contains('class')) {
        headerMap[i] = 'class_name';
      } else if (h.contains('phone') || h.contains('mobile') || h.contains('contact')) {
        headerMap[i] = 'phone';
      } else if (h.contains('email')) {
        headerMap[i] = 'email';
      } else if (h.contains('password') || h.contains('pass')) {
        headerMap[i] = 'password';
      } else if (h.contains('name')) {
        headerMap[i] = 'full_name';
      }
    }

    // Must map at least name, email, and password
    if (!headerMap.values.contains('full_name') ||
        !headerMap.values.contains('email') ||
        !headerMap.values.contains('password')) {
      return [];
    }

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final List<String> cells = _splitCsvLine(line);
      final Map<String, String> user = {};

      headerMap.forEach((index, field) {
        if (index < cells.length) {
          user[field] = cells[index].trim();
        } else {
          user[field] = '';
        }
      });

      // Filter rows without names
      if (user['full_name'] != null && user['full_name']!.isNotEmpty) {
        parsedUsers.add(user);
      }
    }

    return parsedUsers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build columns for AzureGrid
    final List<AzureGridColumn<Map<String, dynamic>>> columns = [
      AzureGridColumn(
        label: 'User ID',
        width: 110,
        cellBuilder: (user) => Text(
          user['user_id'] ?? 'N/A',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        compare: (a, b) => (a['user_id'] ?? '').compareTo(b['user_id'] ?? ''),
      ),
      AzureGridColumn(
        label: 'Name',
        width: 220,
        cellBuilder: (user) {
          final name = user['full_name'] ?? 'Unknown';
          final email = user['email'] ?? '';
          return Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _getRoleColor(user['role'] ?? '').withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(user['role'] ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        compare: (a, b) => (a['full_name'] ?? '').compareTo(b['full_name'] ?? ''),
      ),
      AzureGridColumn(
        label: 'Role',
        width: 140,
        cellBuilder: (user) {
          final role = user['role'] ?? 'user';
          final label = _roleLabels[role] ?? role;
          final color = _getRoleColor(role);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        compare: (a, b) => (a['role'] ?? '').compareTo(b['role'] ?? ''),
      ),
      AzureGridColumn(
        label: 'School / Institution',
        width: 220,
        cellBuilder: (user) {
          final schoolName = user['school_name'] ?? 'System-wide';
          final isSuspended = user['school_status'] == 'suspended';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                schoolName,
                style: GoogleFonts.dmSans(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isSuspended) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    'SUSPENDED',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFFEF4444),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        compare: (a, b) => (a['school_name'] ?? '').compareTo(b['school_name'] ?? ''),
      ),
      AzureGridColumn(
        label: 'Class',
        width: 90,
        cellBuilder: (user) => Text(
          user['class'] ?? '--',
          style: GoogleFonts.dmSans(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        compare: (a, b) => (a['class'] ?? '').compareTo(b['class'] ?? ''),
      ),
      AzureGridColumn(
        label: 'Status',
        width: 120,
        cellBuilder: (user) {
          final isSuspended = user['school_status'] == 'suspended';
          final statusColor = isSuspended ? const Color(0xFFEF4444) : const Color(0xFF10B981);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isSuspended ? 'Suspended' : 'Active',
                style: GoogleFonts.dmSans(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
      AzureGridColumn(
        label: 'Actions',
        width: 140,
        cellBuilder: (user) {
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 16),
                tooltip: 'Impersonate Support',
                onPressed: () {
                  _showSnackBar('Impersonating ${user['full_name']}...');
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 16),
                tooltip: 'Edit Profile',
                onPressed: () {
                  _showEditUserDialog(user);
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                tooltip: 'Delete User',
                onPressed: () {
                  _showDeleteConfirmationDialog(user);
                },
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          );
        },
      ),
    ];

    // Build filters for AzureGrid
    final List<AzureGridFilter<Map<String, dynamic>>> filters = [
      AzureGridFilter(
        label: 'Role',
        options: _roleLabels.values.toList(),
        filterFn: (user, selectedVal) {
          final role = user['role'] ?? '';
          final label = _roleLabels[role] ?? role;
          return label == selectedVal;
        },
      ),
      AzureGridFilter(
        label: 'School',
        options: _schools.map((s) => s['name'] as String).toList(),
        filterFn: (user, selectedVal) {
          return user['school_name'] == selectedVal;
        },
      ),
      AzureGridFilter(
        label: 'Status',
        options: ['Active', 'Suspended'],
        filterFn: (user, selectedVal) {
          final isSuspended = user['school_status'] == 'suspended';
          return selectedVal == 'Suspended' ? isSuspended : !isSuspended;
        },
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'User Management Directory',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: OutlinedButton.icon(
              onPressed: _showBulkImportDialog,
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: Text(
                'Bulk Import',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateUserDialog,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Create User',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _loadingUsers || _loadingSchools
                  ? const Center(child: CircularProgressIndicator())
                  : AzureGrid<Map<String, dynamic>>(
                      title: 'All System Users',
                      items: _users,
                      columns: columns,
                      filters: filters,
                      defaultPageSize: 10,
                      enableSelection: true,
                      loading: _loadingUsers,
                      onRefresh: () {
                        _fetchUsers();
                        _fetchSchools();
                      },
                      searchMatcher: (user) {
                        final name = user['full_name'] ?? '';
                        final email = user['email'] ?? '';
                        final userId = user['user_id'] ?? '';
                        final school = user['school_name'] ?? '';
                        return '$name $email $userId $school';
                      },
                      extraCommandActions: [
                        OutlinedButton.icon(
                          onPressed: () => _exportUsersToCSV(_users),
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: Text(
                            'Export CSV',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                      mobileCardBuilder: (context, user) {
                        final name = user['full_name'] ?? 'Unknown';
                        final email = user['email'] ?? '';
                        final role = user['role'] ?? '';
                        final label = _roleLabels[role] ?? role;
                        final school = user['school_name'] ?? 'System-wide';
                        final isSuspended = user['school_status'] == 'suspended';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E2E38) : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: _getRoleColor(role).withValues(alpha: 0.1),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: _getRoleColor(role),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _getRoleColor(role).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label,
                                      style: GoogleFonts.dmSans(
                                        color: _getRoleColor(role),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      school,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: isSuspended ? const Color(0xFFEF4444) : const Color(0xFF475569),
                                        fontWeight: isSuspended ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 14),
                                        onPressed: () {
                                          _showSnackBar('Impersonating $name...');
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF94A3B8), size: 14),
                                        onPressed: () {
                                          _showEditUserDialog(user);
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 14),
                                        onPressed: () {
                                          _showDeleteConfirmationDialog(user);
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      bulkActions: (context, selectedItems) => [
                        Text(
                          '${selectedItems.length} selected',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () => _exportUsersToCSV(selectedItems),
                          icon: Icon(
                            Icons.file_download_outlined,
                            size: 14,
                            color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                          ),
                          label: Text(
                            'Export Selected',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF10B981).withOpacity(0.5)
                                  : const Color(0xFF059669).withOpacity(0.5),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showBulkChangeSchoolDialog(selectedItems),
                          icon: const Icon(Icons.business_outlined, size: 14),
                          label: const Text('Change School'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showBulkChangeRoleDialog(selectedItems),
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                          label: const Text('Change Role'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showBulkDeleteConfirmationDialog(selectedItems),
                          icon: const Icon(Icons.delete_outline, size: 14),
                          label: const Text('Delete Selected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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

  // ─── BULK ACTION DIALOGS ───────────────────────────────────────────
  void _showBulkChangeSchoolDialog(List<Map<String, dynamic>> selectedItems) {
    String? selectedSchoolId;
    bool isSchoolSuspended = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            // Find current school suspension state
            if (selectedSchoolId != null) {
              final selectedSchoolObj = _schools.firstWhere(
                (s) => s['id'] == selectedSchoolId,
                orElse: () => {},
              );
              isSchoolSuspended = selectedSchoolObj['subscription_status'] == 'suspended';
            } else {
              isSchoolSuspended = false;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Bulk Change School (${selectedItems.length} users)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Select the new school/institution to assign to the selected ${selectedItems.length} users.',
                        style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSchoolId,
                        decoration: const InputDecoration(
                          labelText: 'New School / Institution',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                        ),
                        dropdownColor: Theme.of(context).cardColor,
                        items: _schools.map((s) {
                          final name = s['name'] as String;
                          final isSusp = s['subscription_status'] == 'suspended';
                          return DropdownMenuItem<String>(
                            value: s['id'] as String,
                            child: Text(isSusp ? '$name (SUSPENDED)' : name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateBuilder(() {
                            selectedSchoolId = val;
                          });
                        },
                        validator: (val) => (val == null) ? 'Required' : null,
                      ),
                      if (isSchoolSuspended) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cannot change school: The selected school/institute is currently suspended.',
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFFB91C1C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSchoolSuspended
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final List<String> userIds = selectedItems.map((e) => e['id'] as String).toList();
                            Navigator.of(context).pop();
                            setState(() {
                              _loadingUsers = true;
                            });
                            try {
                              final res = await ApiService().post('/auth/bulk-update', {
                                'user_ids': userIds,
                                'school_id': selectedSchoolId,
                              });
                              if (res['success'] == true) {
                                final int updated = res['updated'] ?? 0;
                                final int failed = res['failed'] ?? 0;
                                _showSnackBar('Successfully moved $updated users to new school. (Failed: $failed)');
                                _fetchUsers();
                              } else {
                                _showSnackBar(res['detail'] ?? 'Bulk update failed', isError: true);
                              }
                            } catch (e) {
                              _showSnackBar('Bulk update error: $e', isError: true);
                            } finally {
                              setState(() {
                                _loadingUsers = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Change School'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkChangeRoleDialog(List<Map<String, dynamic>> selectedItems) {
    String selectedRole = 'student';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Bulk Change Role (${selectedItems.length} users)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select the new role to assign to the selected ${selectedItems.length} users.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'New Role',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                    dropdownColor: Theme.of(context).cardColor,
                    items: _roleLabels.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        selectedRole = val;
                      }
                    },
                    validator: (val) => (val == null) ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final List<String> userIds = selectedItems.map((e) => e['id'] as String).toList();
                  Navigator.of(context).pop();
                  setState(() {
                    _loadingUsers = true;
                  });
                  try {
                    final res = await ApiService().post('/auth/bulk-update', {
                      'user_ids': userIds,
                      'role': selectedRole,
                    });
                    if (res['success'] == true) {
                      final int updated = res['updated'] ?? 0;
                      final int failed = res['failed'] ?? 0;
                      _showSnackBar('Successfully updated role for $updated users. (Failed: $failed)');
                      _fetchUsers();
                    } else {
                      _showSnackBar(res['detail'] ?? 'Bulk update failed', isError: true);
                    }
                  } catch (e) {
                    _showSnackBar('Bulk update error: $e', isError: true);
                  } finally {
                    setState(() {
                      _loadingUsers = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Change Role'),
            ),
          ],
        );
      },
    );
  }

  void _showBulkDeleteConfirmationDialog(List<Map<String, dynamic>> selectedItems) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Confirm Bulk Delete',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFEF4444),
            ),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Warning: High Risk Action!',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to permanently delete the ${selectedItems.length} selected users? This will remove their authentication credentials and delete their profiles. This action CANNOT be undone.',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final List<String> userIds = selectedItems.map((e) => e['id'] as String).toList();
                Navigator.of(context).pop();
                setState(() {
                  _loadingUsers = true;
                });
                try {
                  final res = await ApiService().post('/auth/bulk-delete', {
                    'user_ids': userIds,
                  });
                  if (res['success'] == true) {
                    final int deleted = res['deleted'] ?? 0;
                    final int failed = res['failed'] ?? 0;
                    _showSnackBar('Successfully deleted $deleted users. (Failed: $failed)');
                    _fetchUsers();
                  } else {
                    _showSnackBar(res['detail'] ?? 'Bulk delete failed', isError: true);
                  }
                } catch (e) {
                  _showSnackBar('Bulk delete error: $e', isError: true);
                } finally {
                  setState(() {
                    _loadingUsers = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Users'),
            ),
          ],
        );
      },
    );
  }

  // ─── BULK IMPORT DIALOG ────────────────────────────────────────────
  void _showBulkImportDialog() {
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'student';
    String? selectedSchoolId;
    bool isSchoolSuspended = false;
    
    // Dialog state for parsed file preview
    List<Map<String, String>> parsedRows = [];
    String fileName = '';
    String? fileError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final showSchoolSelect = selectedRole != 'super_admin';

            // Find current school suspension state
            if (showSchoolSelect && selectedSchoolId != null) {
              final selectedSchoolObj = _schools.firstWhere(
                (s) => s['id'] == selectedSchoolId,
                orElse: () => {},
              );
              isSchoolSuspended = selectedSchoolObj['subscription_status'] == 'suspended';
            } else {
              isSchoolSuspended = false;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Bulk Import Users via CSV',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role to Assign',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: Theme.of(context).cardColor,
                          items: _roleLabels.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() {
                                selectedRole = val;
                                if (selectedRole == 'super_admin') {
                                  selectedSchoolId = null;
                                }
                              });
                            }
                          },
                        ),
                        if (showSchoolSelect) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSchoolId,
                            decoration: const InputDecoration(
                              labelText: 'School / Institution',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            ),
                            dropdownColor: Theme.of(context).cardColor,
                            items: _schools.map((s) {
                              final name = s['name'] as String;
                              final isSusp = s['subscription_status'] == 'suspended';
                              return DropdownMenuItem<String>(
                                value: s['id'] as String,
                                child: Text(isSusp ? '$name (SUSPENDED)' : name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateBuilder(() {
                                selectedSchoolId = val;
                              });
                            },
                            validator: (val) => (val == null) ? 'Required for non-superadmin users' : null,
                          ),
                        ],
                        if (isSchoolSuspended) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot import users: The selected school/institute is currently suspended.',
                                    style: GoogleFonts.dmSans(
                                      color: const Color(0xFFB91C1C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Import Data File',
                              style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            TextButton.icon(
                              onPressed: _downloadCSVTemplate,
                              icon: const Icon(Icons.file_download, size: 16),
                              label: const Text('Download CSV Template'),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: isSchoolSuspended
                                  ? null
                                  : () {
                                      final uploadInput = html.FileUploadInputElement()..accept = '.csv';
                                      uploadInput.click();
                                      uploadInput.onChange.listen((e) {
                                        final files = uploadInput.files;
                                        if (files != null && files.isNotEmpty) {
                                          final file = files[0];
                                          final reader = html.FileReader();
                                          reader.readAsText(file);
                                          reader.onLoadEnd.listen((e) {
                                            final text = reader.result as String;
                                            final parsed = _parseCSV(text);
                                            setStateBuilder(() {
                                              fileName = file.name;
                                              if (parsed.isEmpty) {
                                                fileError = 'Invalid CSV format or headers are missing. Required: Name, Email, Password';
                                                parsedRows = [];
                                              } else {
                                                fileError = null;
                                                parsedRows = parsed;
                                              }
                                            });
                                          });
                                        }
                                      });
                                    },
                              icon: const Icon(Icons.upload_file, size: 16),
                              label: const Text('Upload File'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSchoolSuspended ? Colors.grey : const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                fileName.isNotEmpty ? fileName : 'No file selected',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: fileName.isNotEmpty ? Colors.green : Colors.grey,
                                  fontWeight: fileName.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (fileError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            fileError!,
                            style: GoogleFonts.dmSans(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (parsedRows.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2A1C) : const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'File Parsed Successfully!',
                                      style: GoogleFonts.dmSans(
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Ready to import ${parsedRows.length} users. Valid rows will be created in the selected role and institute.',
                                  style: GoogleFonts.dmSans(
                                    color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (parsedRows.isEmpty || isSchoolSuspended)
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final payload = {
                              'school_id': selectedSchoolId ?? '',
                              'role': selectedRole,
                              'users': parsedRows,
                            };
                            Navigator.of(context).pop();
                            setState(() {
                              _loadingUsers = true;
                            });
                            try {
                              final res = await ApiService().post('/auth/bulk-import', payload);
                              if (res['success'] == true) {
                                final int imported = res['imported'] ?? 0;
                                final int failed = res['failed'] ?? 0;
                                final List<dynamic> errorsList = res['errors'] ?? [];
                                
                                _showImportSummaryDialog(imported, failed, errorsList);
                                _fetchUsers();
                              } else {
                                _showSnackBar(res['detail'] ?? 'Bulk import failed', isError: true);
                              }
                            } catch (e) {
                              _showSnackBar('Bulk import error: $e', isError: true);
                            } finally {
                              setState(() {
                                _loadingUsers = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Summarizes import success/failure metrics
  void _showImportSummaryDialog(int imported, int failed, List<dynamic> errors) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Import Summary',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bulk import completed successfully.',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Successfully Imported: $imported users',
                      style: GoogleFonts.dmSans(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (failed > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Failed Imports: $failed users',
                        style: GoogleFonts.dmSans(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error Log:',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 120,
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ListView.builder(
                      itemCount: errors.length,
                      itemBuilder: (context, idx) {
                        final err = errors[idx] as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• ${err['email']}: ${err['error']}',
                            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.red.shade800),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ─── CRUD DIALOGS ──────────────────────────────────────────────────
  void _showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final classController = TextEditingController();

    String selectedRole = 'student';
    String? selectedSchoolId;
    bool isSchoolSuspended = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            final showSchoolSelect = selectedRole != 'super_admin';
            final showClassInput = selectedRole == 'student';

            // Find current school suspension state
            if (showSchoolSelect && selectedSchoolId != null) {
              final selectedSchoolObj = _schools.firstWhere(
                (s) => s['id'] == selectedSchoolId,
                orElse: () => {},
              );
              isSchoolSuspended = selectedSchoolObj['subscription_status'] == 'suspended';
            } else {
              isSchoolSuspended = false;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Create New User',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(val)) return 'Invalid email format';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          style: const TextStyle(fontSize: 13),
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            helperText: 'Min 8 chars, 1 uppercase, 1 lowercase, 1 digit',
                            helperStyle: TextStyle(fontSize: 10),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required';
                            if (val.length < 8) return 'Min 8 characters';
                            if (!val.contains(RegExp(r'[A-Z]'))) return 'Must contain 1 uppercase letter';
                            if (!val.contains(RegExp(r'[a-z]'))) return 'Must contain 1 lowercase letter';
                            if (!val.contains(RegExp(r'\d'))) return 'Must contain 1 number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: Theme.of(context).cardColor,
                          items: _roleLabels.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() {
                                selectedRole = val;
                                if (selectedRole == 'super_admin') {
                                  selectedSchoolId = null;
                                }
                              });
                            }
                          },
                        ),
                        if (showSchoolSelect) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSchoolId,
                            decoration: const InputDecoration(
                              labelText: 'School / Institution',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            ),
                            dropdownColor: Theme.of(context).cardColor,
                            items: _schools.map((s) {
                              final name = s['name'] as String;
                              final isSusp = s['subscription_status'] == 'suspended';
                              return DropdownMenuItem<String>(
                                value: s['id'] as String,
                                child: Text(isSusp ? '$name (SUSPENDED)' : name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateBuilder(() {
                                selectedSchoolId = val;
                              });
                            },
                            validator: (val) => (val == null) ? 'Required for non-superadmin users' : null,
                          ),
                        ],
                        if (showClassInput) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: classController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Class Name (e.g. 10A)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required for students' : null,
                          ),
                        ],
                        if (isSchoolSuspended) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot create user: The selected school/institute is currently suspended.',
                                    style: GoogleFonts.dmSans(
                                      color: const Color(0xFFB91C1C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSchoolSuspended
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final payload = {
                              'email': emailController.text.trim(),
                              'password': passwordController.text,
                              'full_name': nameController.text.trim(),
                              'role': selectedRole,
                              'school_id': selectedSchoolId ?? '',
                              'class_name': showClassInput ? classController.text.trim() : null,
                            };
                            Navigator.of(context).pop();
                            setState(() {
                              _loadingUsers = true;
                            });
                            try {
                              final res = await ApiService().post('/auth/register', payload);
                              if (res['success'] == true) {
                                _showSnackBar('User created successfully');
                                _fetchUsers();
                              } else {
                                _showSnackBar(res['detail'] ?? 'Registration failed', isError: true);
                              }
                            } catch (e) {
                              _showSnackBar('Creation error: $e', isError: true);
                            } finally {
                              setState(() {
                                _loadingUsers = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user['full_name']);
    final emailController = TextEditingController(text: user['email']);
    final passwordController = TextEditingController();
    final classController = TextEditingController(text: user['class'] ?? '');

    String selectedRole = user['role'] ?? 'student';
    String? selectedSchoolId = user['school_id'];
    bool isSchoolSuspended = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            final showSchoolSelect = selectedRole != 'super_admin';
            final showClassInput = selectedRole == 'student';

            // Find current school suspension state
            if (showSchoolSelect && selectedSchoolId != null) {
              final selectedSchoolObj = _schools.firstWhere(
                (s) => s['id'] == selectedSchoolId,
                orElse: () => {},
              );
              isSchoolSuspended = selectedSchoolObj['subscription_status'] == 'suspended';
            } else {
              isSchoolSuspended = false;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Edit User Details',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Required';
                            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                            if (!emailRegex.hasMatch(val)) return 'Invalid email format';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          style: const TextStyle(fontSize: 13),
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password (Optional)',
                            helperText: 'Leave empty to keep existing password',
                            helperStyle: TextStyle(fontSize: 10),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return null;
                            if (val.length < 8) return 'Min 8 characters';
                            if (!val.contains(RegExp(r'[A-Z]'))) return 'Must contain 1 uppercase letter';
                            if (!val.contains(RegExp(r'[a-z]'))) return 'Must contain 1 lowercase letter';
                            if (!val.contains(RegExp(r'\d'))) return 'Must contain 1 number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: Theme.of(context).cardColor,
                          items: _roleLabels.entries.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(e.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() {
                                selectedRole = val;
                                if (selectedRole == 'super_admin') {
                                  selectedSchoolId = null;
                                }
                              });
                            }
                          },
                        ),
                        if (showSchoolSelect) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSchoolId,
                            decoration: const InputDecoration(
                              labelText: 'School / Institution',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            ),
                            dropdownColor: Theme.of(context).cardColor,
                            items: _schools.map((s) {
                              final name = s['name'] as String;
                              final isSusp = s['subscription_status'] == 'suspended';
                              return DropdownMenuItem<String>(
                                value: s['id'] as String,
                                child: Text(isSusp ? '$name (SUSPENDED)' : name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateBuilder(() {
                                selectedSchoolId = val;
                              });
                            },
                            validator: (val) => (val == null) ? 'Required for non-superadmin users' : null,
                          ),
                        ],
                        if (showClassInput) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: classController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Class Name (e.g. 10A)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required for students' : null,
                          ),
                        ],
                        if (isSchoolSuspended) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cannot update user: The selected school/institute is currently suspended.',
                                    style: GoogleFonts.dmSans(
                                      color: const Color(0xFFB91C1C),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSchoolSuspended
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            final payload = {
                              'full_name': nameController.text.trim(),
                              'email': emailController.text.trim(),
                              'role': selectedRole,
                              'school_id': selectedSchoolId ?? '',
                              'class_name': showClassInput ? classController.text.trim() : null,
                              if (passwordController.text.isNotEmpty) 'password': passwordController.text,
                            };
                            Navigator.of(context).pop();
                            setState(() {
                              _loadingUsers = true;
                            });
                            try {
                              final res = await ApiService().put('/auth/users/${user['id']}', payload);
                              if (res['success'] == true) {
                                _showSnackBar('User updated successfully');
                                _fetchUsers();
                              } else {
                                _showSnackBar(res['detail'] ?? 'Update failed', isError: true);
                              }
                            } catch (e) {
                              _showSnackBar('Update error: $e', isError: true);
                            } finally {
                              setState(() {
                                _loadingUsers = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Confirm Delete',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to permanently delete user "${user['full_name']}" (${user['email']})? This action cannot be undone.',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _loadingUsers = true;
                });
                try {
                  final res = await ApiService().delete('/auth/user/${user['email']}');
                  if (res['success'] == true) {
                    _showSnackBar('User deleted successfully');
                    _fetchUsers();
                  } else {
                    _showSnackBar(res['detail'] ?? 'Delete failed', isError: true);
                  }
                } catch (e) {
                  _showSnackBar('Delete error: $e', isError: true);
                } finally {
                  setState(() {
                    _loadingUsers = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
