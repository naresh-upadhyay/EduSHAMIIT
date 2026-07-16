import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuditLogScreen extends StatefulWidget {
  final String? initialSearch;
  const AuditLogScreen({super.key, this.initialSearch});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg => _isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF13182C) : Colors.white;
  Color get _selectedRowBg => _isDark ? const Color(0xFF1E204A) : const Color(0xFFEEF2F6);
  Color get _borderColor => _isDark ? Colors.white10 : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary => _isDark ? Colors.white70 : Colors.black54;
  Color get _textFaded => _isDark ? Colors.white54 : Colors.black45;
  Color get _textMuted => _isDark ? Colors.white30 : Colors.black38;

  final ScrollController _horizScrollController = ScrollController();
  // Loading and pagination states
  bool _isLoading = true;
  bool _isLoadingFilters = true;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalEvents = 0;

  // Data lists
  List<dynamic> _logs = [];
  List<dynamic> _institutions = [];
  List<dynamic> _users = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _selectedLog;

  // Selection state for export multiselect
  final Set<String> _selectedLogs = {};

  // Active filter values
  String _selectedInstitution = 'All Institutions';
  String _selectedEventType = 'All Event Types';
  String _selectedUser = 'All Users';
  String _selectedModule = 'All Modules';
  String _selectedStatus = 'All Status';
  DateTimeRange? _dateRange;

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Sorting
  bool _sortAscending = false;

  // Constant Dropdown Options
  final List<String> _eventTypes = [
    'All Event Types',
    'Create',
    'Update',
    'Delete',
    'Login',
    'Login Failed',
    'Export',
    'Backup',
    'Permission Change',
    'Bulk Update'
  ];

  final List<String> _modules = [
    'All Modules',
    'Institutions',
    'Users',
    'Students',
    'Teachers',
    'Authentication',
    'Settings',
    'Reports',
    'System'
  ];

  final List<String> _statuses = ['All Status', 'Success', 'Failed'];

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
    }
    _fetchFilterData();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizScrollController.dispose();
    super.dispose();
  }

  // Fetch institutions and users to populate dropdowns
  Future<void> _fetchFilterData() async {
    setState(() {
      _isLoadingFilters = true;
    });
    try {
      final instRes = await ApiService().get('/admin/audit-logs/institutions', useCache: false);
      final usersRes = await ApiService().get('/admin/audit-logs/users', useCache: false);

      if (!mounted) return;
      setState(() {
        if (instRes['success'] == true) {
          _institutions = instRes['data'] ?? [];
        }
        if (usersRes['success'] == true) {
          _users = usersRes['data'] ?? [];
        }
        _isLoadingFilters = false;
      });
    } catch (e) {
      debugPrint('Error loading filter dropdown data: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFilters = false;
      });
    }
  }

  // Fetch the actual audit logs list and the summary metrics
  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final queryParams = {
        'page': _currentPage,
        'page_size': _pageSize,
        if (_searchController.text.isNotEmpty) 'search': _searchController.text,
        if (_selectedEventType != 'All Event Types') 'event_type': _selectedEventType,
        if (_selectedModule != 'All Modules') 'module': _selectedModule,
        if (_selectedStatus != 'All Status') 'status': _selectedStatus,
        if (_selectedInstitution != 'All Institutions')
          'school_id': _institutions.firstWhere((inst) => inst['name'] == _selectedInstitution)['id'],
        if (_selectedUser != 'All Users') 'search': _selectedUser, // Filter logs where email/name matches
        if (_dateRange != null) 'start_date': DateFormat('yyyy-MM-dd').format(_dateRange!.start),
        if (_dateRange != null) 'end_date': DateFormat('yyyy-MM-dd').format(_dateRange!.end),
      };

      final res = await ApiService().get('/admin/audit-logs', query: queryParams, useCache: false);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (!mounted) return;
        setState(() {
          _logs = data['logs'] ?? [];
          _totalEvents = data['total'] ?? 0;
          _stats = data['stats'] ?? {};

          // Auto-select first log on wide screens if none selected
          if (_logs.isNotEmpty && _selectedLog == null) {
            _selectedLog = _logs.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Export logs to CSV or Excel
  Future<void> _exportLogs([String format = 'csv']) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final queryParams = <String, String>{
        if (token != null) 'token': token,
        if (_selectedLogs.isNotEmpty) 'ids': _selectedLogs.join(','),
        if (_searchController.text.isNotEmpty) 'search': _searchController.text,
        if (_selectedEventType != 'All Event Types') 'event_type': _selectedEventType,
        if (_selectedModule != 'All Modules') 'module': _selectedModule,
        if (_selectedStatus != 'All Status') 'status': _selectedStatus,
        if (_selectedInstitution != 'All Institutions')
          'school_id': _institutions.firstWhere((inst) => inst['name'] == _selectedInstitution)['id'].toString(),
        if (_dateRange != null) 'start_date': DateFormat('yyyy-MM-dd').format(_dateRange!.start),
        if (_dateRange != null) 'end_date': DateFormat('yyyy-MM-dd').format(_dateRange!.end),
        'format': format,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final exportUrl = '${AppConfig.apiBaseUrl}/admin/audit-logs/export?$queryString';
      final uri = Uri.parse(exportUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download/export logs.')),
        );
      }
    } catch (e) {
      debugPrint('Error exporting logs: $e');
    }
  }

  void _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: _cardBg,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _scaffoldBg,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _currentPage = 1;
      });
      _fetchLogs();
    }
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedInstitution = 'All Institutions';
      _selectedEventType = 'All Event Types';
      _selectedUser = 'All Users';
      _selectedModule = 'All Modules';
      _selectedStatus = 'All Status';
      _dateRange = null;
      _currentPage = 1;
    });
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);
    final theme = Theme.of(context);

    final themeData = _isDark
        ? ThemeData.dark().copyWith(
            scaffoldBackgroundColor: _scaffoldBg,
            cardColor: _cardBg,
            primaryColor: theme.primaryColor,
            dividerColor: _borderColor,
          )
        : ThemeData.light().copyWith(
            scaffoldBackgroundColor: _scaffoldBg,
            cardColor: _cardBg,
            primaryColor: theme.primaryColor,
            dividerColor: _borderColor,
          );

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 20),
                  _buildStatsRow(),
                  SizedBox(height: 24),
                  _buildFilterAndSearchRow(),
                  SizedBox(height: 16),
                  SizedBox(
                    height: isMobile ? 700 : 650,
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildLogsTableContainer()),
                              if (_selectedLog != null) ...[
                                SizedBox(width: 20),
                                SizedBox(
                                  width: 380,
                                  child: _buildEventDetailsPanel(),
                                ),
                              ]
                            ],
                          )
                        : _buildLogsTableContainer(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeader() {
    final isMobile = Responsive.isMobile(context);

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audit Logs',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Track and review all system activities and changes across the platform.',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
    final filterActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Institution filter
        _buildDropdownButton(
          value: _selectedInstitution,
          icon: Icons.school_outlined,
          items: ['All Institutions', ..._institutions.map((i) => i['name'] as String)],
          onChanged: (val) {
            setState(() {
              _selectedInstitution = val!;
              _currentPage = 1;
            });
            _fetchLogs();
          },
          width: isMobile ? 150.0 : 200.0,
        ),
        SizedBox(width: 8),
        // Date picker button
        ElevatedButton.icon(
          onPressed: _showDatePicker,
          icon: Icon(Icons.calendar_today_outlined, size: isMobile ? 12 : 16, color: _textSecondary),
          label: Text(
            _dateRange == null
                ? 'Select Dates'
                : '${DateFormat('MMM dd').format(_dateRange!.start)} - ${DateFormat('MMM dd').format(_dateRange!.end)}',
            style: TextStyle(fontSize: isMobile ? 11 : 12, color: _textPrimary),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _cardBg,
            side: BorderSide(color: _borderColor),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 10 : 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(width: 8),
        // Reset filters button
        IconButton(
          icon: Icon(Icons.refresh, color: _textSecondary),
          tooltip: 'Reset Filters',
          onPressed: _resetFilters,
          style: IconButton.styleFrom(
            backgroundColor: _cardBg,
            side: BorderSide(color: _borderColor),
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleColumn,
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: filterActions,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: titleColumn),
        SizedBox(width: 16),
        filterActions,
      ],
    );
  }

  Widget _buildDropdownButton({
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? width,
  }) {
    final isMobile = Responsive.isMobile(context);
    final finalWidth = width ?? (isMobile ? 140.0 : 160.0);

    return SizedBox(
      width: finalWidth,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: isMobile,
            value: value,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: _textFaded, size: isMobile ? 14 : 18),
            dropdownColor: _cardBg,
            style: TextStyle(color: _textPrimary, fontSize: isMobile ? 11 : 12, fontFamily: 'Outfit'),
            items: items.map((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Row(
                  children: [
                    Icon(icon, color: _textSecondary, size: isMobile ? 12 : 14),
                    SizedBox(width: isMobile ? 6 : 8),
                    Expanded(
                      child: Text(
                        val,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _textPrimary, fontSize: isMobile ? 11 : 12, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final list = [
      _buildStatCard(
        title: 'Total Events',
        value: _stats['total_events']?['value']?.toString() ?? '24,589',
        change: _stats['total_events']?['change']?.toString() ?? '18.6',
        isIncrease: _stats['total_events']?['is_increase'] ?? true,
        icon: Icons.article_outlined,
        color: const Color(0xFF4F46E5),
      ),
      _buildStatCard(
        title: 'Critical Events',
        value: _stats['critical_events']?['value']?.toString() ?? '128',
        change: _stats['critical_events']?['change']?.toString() ?? '8.3',
        isIncrease: _stats['critical_events']?['is_increase'] ?? true,
        icon: Icons.shield_outlined,
        color: const Color(0xFF0EA5E9),
      ),
      _buildStatCard(
        title: 'Users Involved',
        value: _stats['users_involved']?['value']?.toString() ?? '342',
        change: _stats['users_involved']?['change']?.toString() ?? '12.4',
        isIncrease: _stats['users_involved']?['is_increase'] ?? true,
        icon: Icons.people_outline_rounded,
        color: const Color(0xFF10B981),
      ),
      _buildStatCard(
        title: 'Failed Attempts',
        value: _stats['failed_attempts']?['value']?.toString() ?? '89',
        change: _stats['failed_attempts']?['change']?.toString() ?? '-4.7',
        isIncrease: _stats['failed_attempts']?['is_increase'] ?? false,
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFFF59E0B),
      ),
      _buildStatCard(
        title: 'Data Changes',
        value: _stats['data_changes']?['value']?.toString() ?? '5,672',
        change: _stats['data_changes']?['change']?.toString() ?? '20.1',
        isIncrease: _stats['data_changes']?['is_increase'] ?? true,
        icon: Icons.storage_outlined,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      if (Responsive.isMobile(context)) {
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(width: 180, child: list[index]),
          ),
        );
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.isTablet(context) ? 3 : 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
        ),
        itemCount: list.length,
        itemBuilder: (context, idx) => list[idx],
      );
    });
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required bool isIncrease,
    required IconData icon,
    required Color color,
  }) {
    final changeText = isIncrease ? '↑ $change%' : '↓ ${change.replaceAll('-', '')}%';
    final trendColor = isIncrease ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: _textFaded, fontSize: 11, fontFamily: 'Outfit'),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                SizedBox(height: 4),
                Text(
                  '$changeText vs last 7 days',
                  style: TextStyle(color: trendColor, fontSize: 9, fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchRow() {
    final isMobile = Responsive.isMobile(context);

    final searchField = TextField(
      controller: _searchController,
      onSubmitted: (_) {
        setState(() {
          _currentPage = 1;
        });
        _fetchLogs();
      },
      style: TextStyle(color: _textPrimary, fontSize: isMobile ? 11 : 12),
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(color: _textMuted, fontSize: 11),
        prefixIcon: Icon(Icons.search, color: _textFaded, size: isMobile ? 12 : 14),
        fillColor: _cardBg,
        filled: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: isMobile ? 6 : 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _borderColor),
        ),
      ),
    );

    final exportButton = PopupMenuButton<String>(
      onSelected: (String format) {
        _exportLogs(format);
      },
      color: _cardBg,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'csv',
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: _textSecondary),
              SizedBox(width: 8),
              Text('Export as CSV', style: TextStyle(color: _textPrimary, fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'excel',
          child: Row(
            children: [
              Icon(Icons.table_chart_outlined, size: 16, color: _textSecondary),
              SizedBox(width: 8),
              Text('Export as Excel', style: TextStyle(color: _textPrimary, fontSize: 12)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: _selectedRowBg,
          border: Border.all(color: const Color(0xFF373A7A)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.file_download_outlined, size: isMobile ? 12 : 14, color: const Color(0xFF818CF8)),
            SizedBox(width: 6),
            Text('Export', style: TextStyle(color: const Color(0xFF818CF8), fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    final eventTypeDropdown = _buildDropdownButton(
      value: _selectedEventType,
      icon: Icons.category_outlined,
      items: _eventTypes,
      onChanged: (val) {
        setState(() {
          _selectedEventType = val!;
          _currentPage = 1;
        });
        _fetchLogs();
      },
      width: isMobile ? 130.0 : 160.0,
    );

    final userDropdown = _buildDropdownButton(
      value: _selectedUser,
      icon: Icons.person_outline,
      items: ['All Users', ..._users.map((u) => (u['user_email'] ?? 'Unknown User') as String)],
      onChanged: (val) {
        setState(() {
          _selectedUser = val!;
          _currentPage = 1;
        });
        _fetchLogs();
      },
      width: isMobile ? 160.0 : 220.0,
    );

    final moduleDropdown = _buildDropdownButton(
      value: _selectedModule,
      icon: Icons.view_module_outlined,
      items: _modules,
      onChanged: (val) {
        setState(() {
          _selectedModule = val!;
          _currentPage = 1;
        });
        _fetchLogs();
      },
      width: isMobile ? 130.0 : 160.0,
    );

    final statusDropdown = _buildDropdownButton(
      value: _selectedStatus,
      icon: Icons.check_circle_outline_rounded,
      items: _statuses,
      onChanged: (val) {
        setState(() {
          _selectedStatus = val!;
          _currentPage = 1;
        });
        _fetchLogs();
      },
      width: isMobile ? 120.0 : 150.0,
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: searchField),
              SizedBox(width: 8),
              exportButton,
            ],
          ),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                eventTypeDropdown,
                SizedBox(width: 8),
                userDropdown,
                SizedBox(width: 8),
                moduleDropdown,
                SizedBox(width: 8),
                statusDropdown,
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: searchField),
        SizedBox(width: 12),
        eventTypeDropdown,
        SizedBox(width: 12),
        userDropdown,
        SizedBox(width: 12),
        moduleDropdown,
        SizedBox(width: 12),
        statusDropdown,
        SizedBox(width: 12),
        exportButton,
      ],
    );
  }

  Widget _buildLogsTableContainer() {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minWidth = isMobile ? 800.0 : 1000.0;
          final useScroll = constraints.maxWidth < minWidth;

          Widget gridContent = SizedBox(
            width: useScroll ? minWidth : constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTableHeader(),
                Divider(height: 1, color: _borderColor),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                      : _logs.isEmpty
                          ? Center(child: Text('No audit logs found.', style: TextStyle(color: _textFaded)))
                          : ListView.builder(
                              itemCount: _logs.length,
                              itemBuilder: (context, index) {
                                final log = _logs[index];
                                return _buildTableRow(log);
                              },
                            ),
                ),
                Divider(height: 1, color: _borderColor),
                _buildTableFooter(),
              ],
            ),
          );

          if (useScroll) {
            return Scrollbar(
              controller: _horizScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizScrollController,
                scrollDirection: Axis.horizontal,
                child: gridContent,
              ),
            );
          }

          return gridContent;
        },
      ),
    );
  }

  Widget _buildTableHeader() {
    final allSelected = _logs.isNotEmpty && _logs.every((l) => _selectedLogs.contains(l['id']?.toString() ?? ''));
    final isMobile = Responsive.isMobile(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: allSelected,
              activeColor: const Color(0xFF6366F1),
              checkColor: Colors.white,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    for (final l in _logs) {
                      final logId = l['id']?.toString();
                      if (logId != null) {
                        _selectedLogs.add(logId);
                      }
                    }
                  } else {
                    for (final l in _logs) {
                      final logId = l['id']?.toString();
                      if (logId != null) {
                        _selectedLogs.remove(logId);
                      }
                    }
                  }
                });
              },
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                  _currentPage = 1;
                });
                _fetchLogs();
              },
              child: Row(
                children: [
                  Text('Time', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(
                    _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 11,
                    color: _textFaded,
                  ),
                ],
              ),
            ),
          ),
          Expanded(flex: 3, child: Text('User', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
          if (!isMobile) ...[
            Expanded(flex: 2, child: Text('Event Type', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('Module', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
          ],
          Expanded(flex: 2, child: Text('Action', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
          if (!isMobile) ...[
            Expanded(flex: 3, child: Text('Resource', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text('IP Address', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
          ],
          Expanded(flex: 2, child: Text('Status', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> log) {
    final isSelected = _selectedLog != null && _selectedLog!['id'] == log['id'];
    final logId = log['id']?.toString() ?? '';
    final isLogChecked = _selectedLogs.contains(logId);
    final isMobile = Responsive.isMobile(context);

    // Format time
    String timeStr = '-';
    try {
      final dt = DateTime.parse(log['created_at']);
      timeStr = DateFormat('MMM dd, yyyy\nhh:mm:ss a').format(dt.toLocal());
    } catch (_) {}

    // Event badge colors
    Color badgeColor = const Color(0xFF6366F1);
    IconData badgeIcon = Icons.info_outline;

    final evType = log['event_type']?.toString().toLowerCase() ?? '';
    if (evType.contains('create')) {
      badgeColor = const Color(0xFF0EA5E9);
      badgeIcon = Icons.add;
    } else if (evType.contains('update')) {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.edit_outlined;
    } else if (evType.contains('delete')) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = Icons.delete_outline;
    } else if (evType.contains('login')) {
      badgeColor = const Color(0xFF8B5CF6);
      badgeIcon = Icons.login;
    } else if (evType.contains('failed')) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = Icons.warning_amber_rounded;
    } else if (evType.contains('backup')) {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.backup_outlined;
    } else if (evType.contains('export')) {
      badgeColor = const Color(0xFF8B5CF6);
      badgeIcon = Icons.file_download_outlined;
    }

    final isSuccess = log['status']?.toString().toLowerCase() == 'success';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLog = log;
        });
        if (isMobile) {
          _showEventDetailsBottomSheet(log);
        }
      },
      child: Container(
        color: isSelected ? _selectedRowBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isLogChecked,
                activeColor: const Color(0xFF6366F1),
                checkColor: Colors.white,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedLogs.add(logId);
                    } else {
                      _selectedLogs.remove(logId);
                    }
                  });
                },
              ),
            ),
            SizedBox(width: 12),
            // Time
            Expanded(
              flex: 2,
              child: Text(
                timeStr,
                style: TextStyle(color: _textPrimary, fontSize: 11, fontFamily: 'Outfit'),
              ),
            ),
            // User details
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
                    child: Text(
                      (log['user_name'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(color: Color(0xFF6366F1), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['user_name'] ?? 'Unknown User',
                          style: TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          log['user_role'] ?? 'User',
                          style: TextStyle(color: _textMuted, fontSize: 9),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Event Type
            if (!isMobile)
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withOpacity(0.24)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, color: badgeColor, size: 10),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                log['event_type'] ?? 'Info',
                                style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Module
            if (!isMobile)
              Expanded(
                flex: 2,
                child: Text(
                  log['module'] ?? 'System',
                  style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: 'Outfit'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Action
            Expanded(
              flex: 2,
              child: Text(
                log['action'] ?? '-',
                style: TextStyle(color: _textSecondary, fontSize: 11, fontFamily: 'Outfit'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Resource
            if (!isMobile)
              Expanded(
                flex: 3,
                child: Text(
                  log['resource'] ?? '-',
                  style: TextStyle(color: _textFaded, fontSize: 11, fontFamily: 'Outfit'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // IP Address
            if (!isMobile)
              Expanded(
                flex: 2,
                child: Text(
                  log['ip_address'] ?? '-',
                  style: TextStyle(color: _textMuted, fontSize: 11, fontFamily: 'Outfit'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Status
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSuccess ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSuccess ? const Color(0xFF10B981).withOpacity(0.24) : const Color(0xFFEF4444).withOpacity(0.24),
                      ),
                    ),
                    child: Text(
                      isSuccess ? 'Success' : 'Failed',
                      style: TextStyle(
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
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

  Widget _buildTableFooter() {
    final startIdx = (_currentPage - 1) * _pageSize + 1;
    final endIdx = startIdx + _logs.length - 1;
    final totalPages = (_totalEvents / _pageSize).ceil();
    final isMobile = Responsive.isMobile(context);

    final infoRow = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(
          _totalEvents > 0 ? 'Showing $startIdx to $endIdx of $_totalEvents events' : 'Showing 0 events',
          style: TextStyle(color: _textFaded, fontSize: 11, fontFamily: 'Outfit'),
        ),
        SizedBox(width: 12),
        Text('|', style: TextStyle(color: _borderColor, fontSize: 11)),
        SizedBox(width: 12),
        Text('Rows per page: ', style: TextStyle(color: _textFaded, fontSize: 11, fontFamily: 'Outfit')),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _pageSize,
            dropdownColor: _cardBg,
            style: TextStyle(color: _textPrimary, fontSize: 11, fontFamily: 'Outfit'),
            icon: Icon(Icons.keyboard_arrow_down, color: _textFaded, size: 14),
            items: [10, 25, 50, 100].map((int val) {
              return DropdownMenuItem<int>(
                value: val,
                child: Text('$val', style: TextStyle(fontSize: 11)),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _pageSize = newValue;
                  _currentPage = 1;
                });
                _fetchLogs();
              }
            },
          ),
        ),
      ],
    );

    final navRow = Row(
      mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.end,
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Prev Button
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: _textPrimary, size: 18),
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                  _fetchLogs();
                }
              : null,
        ),
        // Current Page Indicator
        Text(
          'Page $_currentPage of ${totalPages > 0 ? totalPages : 1}',
          style: TextStyle(color: _textPrimary, fontSize: 11, fontFamily: 'Outfit'),
        ),
        // Next Button
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, color: _textPrimary, size: 18),
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                  _fetchLogs();
                }
              : null,
        ),
      ],
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            infoRow,
            SizedBox(height: 8),
            navRow,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          infoRow,
          navRow,
        ],
      ),
    );
  }

  Widget _buildEventDetailsPanel() {
    final log = _selectedLog;
    if (log == null) return const SizedBox.shrink();

    // Parse time
    String timeStr = '-';
    try {
      final dt = DateTime.parse(log['created_at']);
      timeStr = DateFormat('MMMM dd, yyyy hh:mm:ss a').format(dt.toLocal());
    } catch (_) {}

    final isSuccess = log['status']?.toString().toLowerCase() == 'success';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Event Details',
                style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: Icon(Icons.close, color: _textFaded, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedLog = null;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 10),
          // Action & status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    log['event_type'] ?? 'Action',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSuccess ? 'Successful' : 'Failed',
                  style: TextStyle(color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Event ID', log['id'] ?? '-', canCopy: true),
                  _buildDetailRow('Time', timeStr),
                  _buildDetailRow('User', log['user_name'] ?? 'Unknown User', subtitle: log['user_email']),
                  _buildDetailRow('Role', log['user_role'] ?? 'User'),
                  _buildDetailRow('IP Address', log['ip_address'] ?? '-', canCopy: true),
                  _buildDetailRow('Module', log['module'] ?? '-'),
                  _buildDetailRow('Action', log['action'] ?? '-'),
                  _buildDetailRow('Resource Type', log['resource_type'] ?? '-'),
                  _buildDetailRow('Resource', log['resource'] ?? '-'),
                  SizedBox(height: 16),
                  Text('Changes', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  _buildChangesCodeBlock(log['changes']),
                  SizedBox(height: 16),
                  _buildDetailRow('User Agent', log['user_agent'] ?? 'unknown', isMonospace: true),
                  _buildDetailRow('Session ID', log['session_id'] ?? 'unknown', isMonospace: true),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final sessionId = log['session_id'];
                setState(() {
                  _searchController.text = (sessionId != null && sessionId.isNotEmpty && sessionId != '-')
                      ? sessionId
                      : (log['user_email'] ?? '');
                });
                _fetchLogs();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF312E81),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('View Related Events', style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? subtitle, bool canCopy = false, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: _textFaded, fontSize: 10, fontFamily: 'Outfit')),
              if (canCopy)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $label to clipboard!'), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Icon(Icons.copy, color: _textFaded, size: 10),
                )
            ],
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontFamily: isMonospace ? 'monospace' : 'Outfit',
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 1),
            Text(subtitle, style: TextStyle(color: _textMuted, fontSize: 9)),
          ],
        ],
      ),
    );
  }

  Widget _buildChangesCodeBlock(dynamic changes) {
    String prettyStr = '-';
    if (changes != null) {
      if (changes is Map && changes.isNotEmpty) {
        final buffer = StringBuffer();
        int lineNum = 1;
        changes.forEach((key, val) {
          buffer.writeln(' $lineNum  $key : $val');
          lineNum++;
        });
        prettyStr = buffer.toString().trimRight();
      } else {
        prettyStr = jsonEncode(changes);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _scaffoldBg,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        prettyStr,
        style: TextStyle(
          color: Color(0xFF10B981),
          fontSize: 10,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }

  void _showEventDetailsBottomSheet(Map<String, dynamic> log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: _buildEventDetailsPanel(),
            );
          },
        );
      },
    );
  }
}
