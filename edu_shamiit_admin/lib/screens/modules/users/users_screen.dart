import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/widgets/azure_grid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends StatefulWidget {
  final String? initialRole;
  const AdminUsersScreen({super.key, this.initialRole});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _schools = [];
  bool _loadingUsers = true;
  bool _loadingSchools = true;
  bool _loadingStats = true;
  bool _isInitialLoad = true;
  Map<String, dynamic>? _statsData;

  // Filter states
  String _searchQuery = '';
  String _selectedRole = 'All';
  String _selectedStatus = 'All';
  String _selectedInstitution = 'All';
  String _selectedDepartment = 'All';

  // Selection states
  final Set<String> _selectedUserIds = {};

  // Pagination states
  int _currentPage = 1;
  int _pageSize = 10;

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
    if (widget.initialRole != null) {
      final roleKey = widget.initialRole!.toLowerCase().replaceAll(' ', '_');
      if (_roleLabels.containsKey(roleKey)) {
        _selectedRole = _roleLabels[roleKey]!;
      } else {
        final matchingValue = _roleLabels.values.firstWhere(
          (val) => val.toLowerCase() == widget.initialRole!.toLowerCase(),
          orElse: () => 'All',
        );
        _selectedRole = matchingValue;
      }
    }
    _fetchUsers();
    _fetchSchools();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _loadingStats = true;
    });
    try {
      String queryStr = '';
      if (_selectedInstitution != 'All') {
        final school = _schools.firstWhere(
          (s) => s['name'] == _selectedInstitution,
          orElse: () => <String, dynamic>{},
        );
        if (school['id'] != null) {
          queryStr = '?school_id=${school['id']}';
        }
      }
      final res = await ApiService().get('/auth/users/stats$queryStr', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _statsData = Map<String, dynamic>.from(res['data']);
        });
      }
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    } finally {
      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _loadingUsers = true;
    });
    try {
      final List<String> queryParts = [];
      if (_searchQuery.isNotEmpty) {
        queryParts.add('q=${Uri.encodeComponent(_searchQuery)}');
      }
      if (_selectedRole != 'All') {
        final String roleKey = _roleLabels.entries
            .firstWhere((e) => e.value == _selectedRole, orElse: () => MapEntry(_selectedRole, _selectedRole))
            .key;
        queryParts.add('role=$roleKey');
      }
      if (_selectedStatus != 'All') {
        queryParts.add('status=$_selectedStatus');
      }
      if (_selectedInstitution != 'All') {
        final school = _schools.firstWhere(
          (s) => s['name'] == _selectedInstitution,
          orElse: () => <String, dynamic>{},
        );
        if (school['id'] != null) {
          queryParts.add('school_id=${school['id']}');
        }
      }
      if (_selectedDepartment != 'All') {
        queryParts.add('department=${Uri.encodeComponent(_selectedDepartment)}');
      }

      final String queryStr = queryParts.isNotEmpty ? '?${queryParts.join('&')}' : '';
      final res = await ApiService().get('/auth/users$queryStr', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(res['data']);
          _selectedUserIds.clear();
          final maxPage = (_users.length / _pageSize).ceil();
          if (_currentPage > maxPage) {
            _currentPage = maxPage > 0 ? maxPage : 1;
          }
        });
        _fetchStats();
      }
    } catch (e) {
      _showSnackBar('Failed to load users: $e', isError: true);
    } finally {
      setState(() {
        _loadingUsers = false;
        _isInitialLoad = false;
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

    final scaffoldBg = isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final textMuted = isDark ? Colors.white30 : Colors.black38;
    final accentColor = const Color(0xFF6366F1);

    final totalCount = _statsData?['total_users'] ?? 1248;
    final activeCount = _statsData?['active_users'] ?? 1102;
    final inactiveCount = _statsData?['inactive_users'] ?? 89;
    final lockedCount = _statsData?['locked_users'] ?? 57;
    final newCount = _statsData?['new_this_month'] ?? 34;

    final loginsToday = _statsData?['activity_summary']?['logins_today'] ?? 342;
    final regsToday = _statsData?['activity_summary']?['new_registrations_today'] ?? 18;

    final filteredUsers = _users.where((user) {
      final role = user['role'] ?? '';
      final label = _roleLabels[role] ?? role;
      final schoolName = user['school_name'] ?? 'System-wide';
      final status = user['status'] ?? 'Active';
      final dept = user['department'] ?? '';

      if (_selectedRole != 'All' && label != _selectedRole) return false;
      if (_selectedStatus != 'All' && status != _selectedStatus) return false;
      if (_selectedInstitution != 'All' && schoolName != _selectedInstitution) return false;
      if (_selectedDepartment != 'All' && dept != _selectedDepartment) return false;
      
      if (_searchQuery.isNotEmpty) {
        final name = (user['full_name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final uid = (user['user_id'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !uid.contains(q)) return false;
      }
      return true;
    }).toList();

    final totalFiltered = filteredUsers.length;
    final maxPage = (totalFiltered / _pageSize).ceil();
    final displayPage = _currentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _currentPage;
    
    final startIndex = (displayPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > totalFiltered ? totalFiltered : startIndex + _pageSize;
    
    final paginatedUsers = totalFiltered > 0 ? filteredUsers.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: _isInitialLoad || _loadingSchools
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Title/Header Row
                    _buildHeader(isDark, textPrimary, textSecondary, accentColor),
                    const SizedBox(height: 12),
                    if (_loadingUsers)
                      const ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        ),
                      )
                    else
                      const SizedBox(height: 3),
                    const SizedBox(height: 12),

                    // 2. Metrics Row
                    _buildMetricsRow(isDark, cardBg, borderColor, textPrimary, textSecondary, totalCount, activeCount, inactiveCount, lockedCount, newCount),
                    const SizedBox(height: 24),

                    // 3. Main Split Columns
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isLargeScreen = constraints.maxWidth > 1200;
                        if (isLargeScreen) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildLeftColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, paginatedUsers, totalFiltered, displayPage),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 330,
                                child: _buildRightColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, totalCount, activeCount, inactiveCount, lockedCount, newCount, loginsToday, regsToday),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLeftColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, paginatedUsers, totalFiltered, displayPage),
                              const SizedBox(height: 24),
                              _buildRightColumn(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, totalCount, activeCount, inactiveCount, lockedCount, newCount, loginsToday, regsToday),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary, Color accentColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.outfit(color: textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage system users, roles, and access permissions across all institutions.',
          style: GoogleFonts.dmSans(color: textSecondary, fontSize: 13),
        ),
      ],
    );

    final actionsContent = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedInstitution,
              dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
              style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
              icon: Icon(Icons.business_outlined, color: accentColor, size: 16),
              items: ['All', ..._schools.map((s) => s['name'] as String)].map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, size: 14, color: accentColor),
                      const SizedBox(width: 8),
                      Text(val.length > 20 ? '${val.substring(0, 17)}...' : val),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedInstitution = val;
                    _currentPage = 1;
                    _fetchUsers();
                  });
                }
              },
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _showCreateUserDialog,
          icon: const Icon(Icons.add, size: 16),
          label: Text(
            'Add New User',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 420,
          ),
          child: headerContent,
        ),
        actionsContent,
      ],
    );
  }

  Widget _buildMetricsRow(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    int totalCount,
    int activeCount,
    int inactiveCount,
    int lockedCount,
    int newCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int count = width > 750 ? 5 : (width > 550 ? 3 : 2);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              'Total Users',
              totalCount.toString(),
              '8.8% up',
              true,
              const Color(0xFF6366F1),
              Icons.people_outline,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
              width,
              count,
            ),
            _buildMetricCard(
              'Active Users',
              activeCount.toString(),
              '6.3% up',
              true,
              const Color(0xFF10B981),
              Icons.person_outline,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
              width,
              count,
            ),
            _buildMetricCard(
              'Inactive Users',
              inactiveCount.toString(),
              '3.2% up',
              true,
              const Color(0xFFF59E0B),
              Icons.person_off_outlined,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
              width,
              count,
            ),
            _buildMetricCard(
              'Locked Users',
              lockedCount.toString(),
              '1.4% down',
              false,
              const Color(0xFFEF4444),
              Icons.lock_outline,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
              width,
              count,
            ),
            _buildMetricCard(
              'New This Month',
              newCount.toString(),
              '12.8% up',
              true,
              const Color(0xFF06B6D4),
              Icons.person_add_alt_1_outlined,
              cardBg,
              borderColor,
              textPrimary,
              textSecondary,
              width,
              count,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String trend,
    bool isTrendUp,
    Color color,
    IconData icon,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    double totalWidth,
    int cardsPerRow,
  ) {
    final double cardWidth = (totalWidth - (cardsPerRow - 1) * 12) / cardsPerRow;
    return Container(
      width: cardWidth > 130 ? cardWidth : 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isTrendUp ? Icons.trending_up : Icons.trending_down,
                color: isTrendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 11,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  trend,
                  style: GoogleFonts.dmSans(
                    color: isTrendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUserCard(
    Map<String, dynamic> user,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color accentColor,
  ) {
    final isSelected = _selectedUserIds.contains(user['id']);
    final name = user['full_name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'student';
    final roleLabel = _roleLabels[role] ?? role;
    final roleColor = _getRoleColor(role);
    final schoolName = user['school_name'] ?? 'System-wide';
    final dept = user['department'] ?? 'N/A';
    
    final status = user['status'] ?? 'Active';
    Color statusColor = const Color(0xFF10B981);
    if (status == 'Inactive') statusColor = const Color(0xFF64748B);
    if (status == 'Locked') statusColor = const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B223C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: accentColor,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      if (user['id'] != null) _selectedUserIds.add(user['id']);
                    } else {
                      _selectedUserIds.remove(user['id']);
                    }
                  });
                },
              ),
              CircleAvatar(
                radius: 18,
                backgroundImage: user['avatar_url'] != null && user['avatar_url'].isNotEmpty
                    ? NetworkImage(user['avatar_url'])
                    : null,
                backgroundColor: roleColor.withOpacity(0.1),
                child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.dmSans(color: textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: roleColor.withOpacity(0.2)),
                ),
                child: Text(
                  roleLabel,
                  style: GoogleFonts.dmSans(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: GoogleFonts.dmSans(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.business, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  schoolName,
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dept,
                  style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${user['created_at'] != null ? user['created_at'].toString().split('T')[0] : '--'}',
                style: GoogleFonts.dmSans(color: textMuted, fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                    color: accentColor,
                    onPressed: () => _showUserDetailDialog(user),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: textSecondary,
                    onPressed: () => _showEditUserDialog(user),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: const Color(0xFFEF4444),
                    onPressed: () => _showDeleteConfirmationDialog(user),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color accentColor,
    List<Map<String, dynamic>> paginatedUsers,
    int totalFiltered,
    int displayPage,
  ) {
    final maxPage = (totalFiltered / _pageSize).ceil();
    final startIndex = (displayPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > totalFiltered ? totalFiltered : startIndex + _pageSize;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFiltersRow(isDark, cardBg, borderColor, textPrimary, textSecondary, accentColor),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedUserIds.isNotEmpty)
                _buildBulkActionsBar(isDark, borderColor, textPrimary, accentColor, totalFiltered)
              else
                const SizedBox.shrink(),
              
              isMobile
                  ? Column(
                      children: paginatedUsers.map((user) {
                        return _buildMobileUserCard(user, isDark, textPrimary, textSecondary, textMuted, accentColor);
                      }).toList(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        horizontalMargin: 16,
                        columnSpacing: 24,
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value: paginatedUsers.isNotEmpty &&
                                  paginatedUsers.every((u) => _selectedUserIds.contains(u['id'])),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    for (var u in paginatedUsers) {
                                      if (u['id'] != null) _selectedUserIds.add(u['id']);
                                    }
                                  } else {
                                    for (var u in paginatedUsers) {
                                      _selectedUserIds.remove(u['id']);
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          TextColumn('User', textSecondary, width: 220),
                          TextColumn('Role', textSecondary, width: 90),
                          TextColumn('Institution', textSecondary, width: 160),
                          TextColumn('Department', textSecondary, width: 90),
                          TextColumn('Status', textSecondary, width: 85),
                          TextColumn('Last Login', textSecondary, width: 90),
                          TextColumn('Created On', textSecondary, width: 90),
                          TextColumn('Actions', textSecondary, width: 150),
                        ],
                        rows: paginatedUsers.map((user) {
                          final isSelected = _selectedUserIds.contains(user['id']);
                          final name = user['full_name'] ?? 'Unknown';
                          final email = user['email'] ?? '';
                          final role = user['role'] ?? 'student';
                          final roleLabel = _roleLabels[role] ?? role;
                          final roleColor = _getRoleColor(role);
                          final schoolName = user['school_name'] ?? 'System-wide';
                          final dept = user['department'] ?? 'N/A';
                          
                          final status = user['status'] ?? 'Active';
                          Color statusColor = const Color(0xFF10B981);
                          if (status == 'Inactive') statusColor = const Color(0xFF64748B);
                          if (status == 'Locked') statusColor = const Color(0xFFEF4444);

                          String lastLoginDateStr = '--';
                          if (user['last_login'] != null) {
                            try {
                              final parsed = DateTime.parse(user['last_login'].toString()).toLocal();
                              lastLoginDateStr = "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
                            } catch (_) {
                              lastLoginDateStr = user['last_login'].toString().split('T')[0];
                            }
                          }
                          final createdOnDateStr = user['created_at'] != null 
                              ? user['created_at'].toString().split('T')[0]
                              : '--';

                          return DataRow(
                            selected: isSelected,
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        if (user['id'] != null) _selectedUserIds.add(user['id']);
                                      } else {
                                        _selectedUserIds.remove(user['id']);
                                      }
                                    });
                                  },
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundImage: user['avatar_url'] != null && user['avatar_url'].isNotEmpty
                                            ? NetworkImage(user['avatar_url'])
                                            : null,
                                        backgroundColor: roleColor.withOpacity(0.1),
                                        child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                                            ? Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: roleColor,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.dmSans(
                                                  color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (email.isNotEmpty)
                                              Text(
                                                email,
                                                style: GoogleFonts.dmSans(color: textMuted, fontSize: 11),
                                                maxLines: 1,
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
                                  width: 90,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: roleColor.withOpacity(0.24)),
                                      ),
                                      child: Text(
                                        roleLabel,
                                        style: GoogleFonts.dmSans(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    schoolName,
                                    style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    dept,
                                    style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          status,
                                          style: GoogleFonts.dmSans(
                                              color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    lastLoginDateStr,
                                    style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    createdOnDateStr,
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
                                      IconButton(
                                        icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                        color: accentColor,
                                        tooltip: 'View Profile Details',
                                        onPressed: () => _showUserDetailDialog(user),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        color: textSecondary,
                                        tooltip: 'Edit User',
                                        onPressed: () => _showEditUserDialog(user),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        color: const Color(0xFFEF4444),
                                        tooltip: 'Delete User',
                                        onPressed: () => _showDeleteConfirmationDialog(user),
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
                child: isMobile
                    ? Column(
                        children: [
                          Text(
                            'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered users',
                            style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              }).toList(),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 16),
                                color: displayPage < maxPage ? textPrimary : textMuted,
                                onPressed: displayPage < maxPage
                                    ? () => setState(() => _currentPage = displayPage + 1)
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing ${totalFiltered == 0 ? 0 : startIndex + 1} to $endIndex of $totalFiltered users',
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
                              }).toList(),
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
        ),
      ],
    );
  }

  DataColumn TextColumn(String label, Color textSecondary, {double? width}) {
    return DataColumn(
      label: width != null
          ? SizedBox(
              width: width,
              child: Text(
                label,
                style: GoogleFonts.dmSans(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              label,
              style: GoogleFonts.dmSans(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
            ),
    );
  }

  Widget _buildFiltersRow(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color accentColor,
  ) {
    final List<String> depts = [
      'All',
      'Administration',
      'Academic',
      'Finance',
      'Science',
      'Library',
      'IT Support',
      'Mathematics',
      'Student Affairs',
      'Front Office',
      'Transport'
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          width: 260,
          height: 38,
          child: TextField(
            style: TextStyle(color: textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search users by name, email or ID...',
              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 12),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.white30 : Colors.black38, size: 16),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              filled: true,
              fillColor: isDark ? const Color(0xFF13182C) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accentColor),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
              _fetchUsers();
            },
          ),
        ),
        _buildDropdown(
          'All Roles',
          _selectedRole,
          ['All', ..._roleLabels.values],
          (val) {
            setState(() {
              _selectedRole = val;
              _currentPage = 1;
              _fetchUsers();
            });
          },
          isDark,
          cardBg,
          borderColor,
          textPrimary,
        ),
        _buildDropdown(
          'All Status',
          _selectedStatus,
          ['All', 'Active', 'Inactive', 'Locked'],
          (val) {
            setState(() {
              _selectedStatus = val;
              _currentPage = 1;
              _fetchUsers();
            });
          },
          isDark,
          cardBg,
          borderColor,
          textPrimary,
        ),
        _buildDropdown(
          'All Departments',
          _selectedDepartment,
          depts,
          (val) {
            setState(() {
              _selectedDepartment = val;
              _currentPage = 1;
              _fetchUsers();
            });
          },
          isDark,
          cardBg,
          borderColor,
          textPrimary,
        ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _searchQuery = '';
              _selectedRole = 'All';
              _selectedStatus = 'All';
              _selectedInstitution = 'All';
              _selectedDepartment = 'All';
              _currentPage = 1;
              _fetchUsers();
            });
            _showSnackBar('Filters reset');
          },
          icon: const Icon(Icons.filter_list, size: 14),
          label: Text('Reset Filters', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: textSecondary,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String hint,
    String currentValue,
    List<String> items,
    Function(String) onChanged,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 38,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(currentValue) ? currentValue : 'All',
          dropdownColor: cardBg,
          style: TextStyle(color: textPrimary, fontSize: 12),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val == 'All' ? hint : val),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBulkActionsBar(
    bool isDark,
    Color borderColor,
    Color textPrimary,
    Color accentColor,
    int totalFiltered,
  ) {
    final selectedItems = _users.where((u) => _selectedUserIds.contains(u['id'])).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E204A) : const Color(0xFFEEF2F6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${_selectedUserIds.length} items selected',
            style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _exportUsersToCSV(selectedItems),
            icon: const Icon(Icons.download_outlined, size: 14),
            label: const Text('Export Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showBulkChangeSchoolDialog(selectedItems),
            icon: const Icon(Icons.business_outlined, size: 14),
            label: const Text('Change School', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showBulkChangeRoleDialog(selectedItems),
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
            label: const Text('Change Role', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showBulkDeleteConfirmationDialog(selectedItems),
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text('Delete Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color accentColor,
    int totalCount,
    int activeCount,
    int inactiveCount,
    int lockedCount,
    int newCount,
    int loginsToday,
    int regsToday,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Overview',
                style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildOverviewRow('Total Users', totalCount.toString(), textSecondary, textPrimary, Icons.people_alt_outlined, const Color(0xFF6366F1)),
              _buildOverviewRow('Active Users', '$activeCount (${totalCount == 0 ? 0 : (activeCount/totalCount*100).toStringAsFixed(1)}%)', textSecondary, textPrimary, Icons.person_outline, const Color(0xFF10B981)),
              _buildOverviewRow('Inactive Users', '$inactiveCount (${totalCount == 0 ? 0 : (inactiveCount/totalCount*100).toStringAsFixed(1)}%)', textSecondary, textPrimary, Icons.person_off_outlined, const Color(0xFFF59E0B)),
              _buildOverviewRow('Locked Users', '$lockedCount (${totalCount == 0 ? 0 : (lockedCount/totalCount*100).toStringAsFixed(1)}%)', textSecondary, textPrimary, Icons.lock_outline, const Color(0xFFEF4444)),
              _buildOverviewRow('Users Created This Month', newCount.toString(), textSecondary, textPrimary, Icons.person_add_outlined, const Color(0xFF06B6D4)),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showSnackBar('Viewing detailed report...'),
                  child: Text(
                    'View detailed report →',
                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users by Role',
                style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildRoleChart(isDark, totalCount, textPrimary, textMuted),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showSnackBar('Viewing all roles...'),
                  child: Text(
                    'View all roles →',
                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildQuickAction('Add New User', 'Create a new system user', Icons.person_add_alt_1_outlined, _showCreateUserDialog, accentColor),
              _buildQuickAction('Import Users', 'Bulk import users via CSV', Icons.cloud_upload_outlined, _showBulkImportDialog, const Color(0xFF10B981)),
              _buildQuickAction('Manage Roles', 'Create and manage user roles', Icons.admin_panel_settings_outlined, () => context.go('/admin/roles'), const Color(0xFF8B5CF6)),
              _buildQuickAction('Permission Matrix', 'View role & permission overview', Icons.grid_view_outlined, () => context.go('/admin/roles'), const Color(0xFFEC4899)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Activity (Today)',
                style: GoogleFonts.outfit(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Logins', style: TextStyle(color: textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          loginsToday.toString(),
                          style: GoogleFonts.outfit(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.arrow_upward, color: Color(0xFF10B981), size: 10),
                            SizedBox(width: 2),
                            Text('12.4%', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 50, color: borderColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Registrations', style: TextStyle(color: textSecondary, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(
                          regsToday.toString(),
                          style: GoogleFonts.outfit(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.arrow_upward, color: Color(0xFF10B981), size: 10),
                            SizedBox(width: 2),
                            Text('5.3%', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
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

  Widget _buildOverviewRow(String label, String value, Color textSecondary, Color textPrimary, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 11)),
            ],
          ),
          Text(value, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRoleChart(bool isDark, int totalCount, Color textPrimary, Color textMuted) {
    int studentCount = 0;
    int teacherCount = 0;
    int adminCount = 0;
    int managerCount = 0;
    int othersCount = 0;

    for (var u in _users) {
      final role = u['role'] ?? 'student';
      if (role == 'student') {
        studentCount++;
      } else if (role == 'teacher') {
        teacherCount++;
      } else if (role == 'admin' || role == 'super_admin' || role == 'student_admin' || role == 'teacher_admin') {
        adminCount++;
      } else if (role == 'principal' || role == 'director' || role == 'hr' || role == 'finance') {
        managerCount++;
      } else {
        othersCount++;
      }
    }

    if (totalCount == 1248 && _users.isEmpty) {
      studentCount = 512;
      teacherCount = 458;
      adminCount = 12;
      managerCount = 24;
      othersCount = 242;
    }

    final int computedTotal = studentCount + teacherCount + adminCount + managerCount + othersCount;

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: RoleDonutChartPainter(
                  counts: {
                    'student': studentCount,
                    'teacher': teacherCount,
                    'admin': adminCount,
                    'principal': managerCount,
                    'others': othersCount,
                  },
                  strokeWidth: 10,
                  isDark: isDark,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(color: textMuted, fontSize: 9),
                  ),
                  Text(
                    computedTotal.toString(),
                    style: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow('Admin', adminCount, computedTotal, const Color(0xFF3B82F6)),
              _buildLegendRow('Manager', managerCount, computedTotal, const Color(0xFF8B5CF6)),
              _buildLegendRow('Teacher', teacherCount, computedTotal, const Color(0xFF0D9488)),
              _buildLegendRow('Student', studentCount, computedTotal, const Color(0xFF10B981)),
              _buildLegendRow('Others', othersCount, computedTotal, const Color(0xFF64748B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(String label, int count, int total, Color color) {
    final double percent = total == 0 ? 0 : (count / total * 100);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final textMuted = isDark ? Colors.white54 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 10, color: textSecondary)),
            ],
          ),
          Text(
            '$count (${percent.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String title, String subtitle, IconData icon, VoidCallback onTap, Color iconColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;
    final textMuted = isDark ? Colors.white30 : Colors.black38;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 9, color: textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  void _showUserDetailDialog(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'Unknown';
    final role = user['role'] ?? 'user';
    final label = _roleLabels[role] ?? role;
    final roleColor = _getRoleColor(role);
    final schoolName = user['school_name'] ?? 'System-wide';
    final dept = user['department'] ?? 'N/A';
    final status = user['status'] ?? 'Active';
    String lastLogin = '--';
    if (user['last_login'] != null) {
      try {
        final parsed = DateTime.parse(user['last_login'].toString()).toLocal();
        lastLogin = DateFormat('MMM dd, yyyy hh:mm a').format(parsed);
      } catch (_) {
        lastLogin = user['last_login'].toString();
      }
    }
    final email = user['email'] ?? 'N/A';
    final phone = user['phone'] ?? 'N/A';
    final gender = user['gender'] ?? 'N/A';
    final dob = user['date_of_birth'] ?? 'N/A';
    final bloodGroup = user['blood_group'] ?? 'N/A';
    final address = user['address'] ?? 'N/A';
    final fatherName = user['father_name'] ?? 'N/A';
    final motherName = user['mother_name'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF13182C) : Colors.white;
        final textPrimary = isDark ? Colors.white : Colors.black87;
        final textSecondary = isDark ? Colors.white70 : Colors.black54;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: user['avatar_url'] != null && user['avatar_url'].isNotEmpty
                    ? NetworkImage(user['avatar_url'])
                    : null,
                backgroundColor: roleColor.withOpacity(0.1),
                child: user['avatar_url'] == null || user['avatar_url'].isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: roleColor),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(label, style: GoogleFonts.dmSans(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  _buildDetailItem('User ID', user['user_id'] ?? 'N/A', textSecondary, textPrimary),
                  _buildDetailItem('Email', email, textSecondary, textPrimary),
                  _buildDetailItem('Phone', phone, textSecondary, textPrimary),
                  _buildDetailItem('School / Institution', schoolName, textSecondary, textPrimary),
                  _buildDetailItem('Department', dept, textSecondary, textPrimary),
                  _buildDetailItem('Status', status, textSecondary, textPrimary),
                  _buildDetailItem('Gender', gender, textSecondary, textPrimary),
                  _buildDetailItem('Date of Birth', dob, textSecondary, textPrimary),
                  _buildDetailItem('Blood Group', bloodGroup, textSecondary, textPrimary),
                  _buildDetailItem('Address', address, textSecondary, textPrimary),
                  _buildDetailItem('Father\'s Name', fatherName, textSecondary, textPrimary),
                  _buildDetailItem('Mother\'s Name', motherName, textSecondary, textPrimary),
                  _buildDetailItem('Last Login', lastLogin, textSecondary, textPrimary),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, Color textSecondary, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.dmSans(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.dmSans(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Bulk Change School (${selectedItems.length} users)',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: (450.0 < MediaQuery.of(context).size.width - 48) ? 450.0 : MediaQuery.of(context).size.width - 48,
                child: SingleChildScrollView(
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
                          isExpanded: true,
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Bulk Change Role (${selectedItems.length} users)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: (450.0 < MediaQuery.of(context).size.width - 48) ? 450.0 : MediaQuery.of(context).size.width - 48,
            child: SingleChildScrollView(
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
                      isExpanded: true,
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
            final isMobile = MediaQuery.of(context).size.width < 600;
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(
                'Bulk Import Users via CSV',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: (500.0 < MediaQuery.of(context).size.width - 48) ? 500.0 : MediaQuery.of(context).size.width - 48,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
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
                            isExpanded: true,
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
                        isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Import Data File',
                                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton.icon(
                                    onPressed: _downloadCSVTemplate,
                                    icon: const Icon(Icons.file_download, size: 14),
                                    label: const Text('Download CSV Template', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
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
                            isExpanded: true,
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
    final departmentController = TextEditingController(text: user['department'] ?? '');

    String selectedRole = user['role'] ?? 'student';
    String selectedStatus = user['status'] ?? 'Active';
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: Theme.of(context).cardColor,
                          items: ['Active', 'Inactive', 'Locked'].map((statusOption) {
                            return DropdownMenuItem<String>(
                              value: statusOption,
                              child: Text(statusOption),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateBuilder(() {
                                selectedStatus = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: departmentController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        if (showSchoolSelect) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
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
                              'status': selectedStatus,
                              'department': departmentController.text.trim().isNotEmpty
                                  ? departmentController.text.trim()
                                  : null,
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

class RoleDonutChartPainter extends CustomPainter {
  final Map<String, int> counts;
  final double strokeWidth;
  final bool isDark;

  RoleDonutChartPainter({
    required this.counts,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final total = counts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) {
      paint.color = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
      canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, paint);
      return;
    }

    final double studentRatio = (counts['student'] ?? 0) / total;
    final double teacherRatio = (counts['teacher'] ?? 0) / total;
    final double adminRatio = ((counts['admin'] ?? 0) + (counts['super_admin'] ?? 0)) / total;
    final double managerRatio = ((counts['principal'] ?? 0) + (counts['director'] ?? 0) + (counts['hr'] ?? 0) + (counts['finance'] ?? 0)) / total;
    final double othersRatio = 1.0 - (studentRatio + teacherRatio + adminRatio + managerRatio);

    double startAngle = -3.141592653589793 / 2;

    if (othersRatio > 0) {
      paint.color = const Color(0xFF64748B);
      final sweepAngle = othersRatio * 2 * 3.141592653589793;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    if (managerRatio > 0) {
      paint.color = const Color(0xFF8B5CF6);
      final sweepAngle = managerRatio * 2 * 3.141592653589793;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    if (adminRatio > 0) {
      paint.color = const Color(0xFF3B82F6);
      final sweepAngle = adminRatio * 2 * 3.141592653589793;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    if (teacherRatio > 0) {
      paint.color = const Color(0xFF0D9488);
      final sweepAngle = teacherRatio * 2 * 3.141592653589793;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    if (studentRatio > 0) {
      paint.color = const Color(0xFF10B981);
      final sweepAngle = studentRatio * 2 * 3.141592653589793;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RoleDonutChartPainter oldDelegate) {
    return true;
  }
}
