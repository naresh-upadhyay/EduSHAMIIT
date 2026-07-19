import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'dart:html' as html;

class AlertsNotificationsScreen extends ConsumerStatefulWidget {
  const AlertsNotificationsScreen({super.key});

  @override
  ConsumerState<AlertsNotificationsScreen> createState() => _AlertsNotificationsScreenState();
}

class _AlertsNotificationsScreenState extends ConsumerState<AlertsNotificationsScreen> {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg => _isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF13182C) : Colors.white;
  Color get _borderColor => _isDark ? Colors.white10 : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);

  bool _isLoading = true;
  List<dynamic> _alerts = [];
  int _totalAlerts = 0;
  int _currentPage = 1;
  int _pageSize = 10;
  String _searchQuery = "";
  
  // Selected Filters
  String _selectedTab = "All Alerts"; // All Alerts, Unread, Critical, Warning, Info, Resolved
  String _selectedCategory = "All Categories";
  String _selectedStatus = "All Status";
  
  // Stats & Breakdown (mocked values or fetched from API)
  Map<String, dynamic> _stats = {
    "total_alerts": 56,
    "unread_alerts": 12,
    "critical_alerts": 5,
    "resolved_alerts": 39
  };
  
  Map<String, dynamic> _breakdown = {
    "critical": 5,
    "high": 18,
    "warning": 12,
    "info": 21
  };

  Map<String, dynamic> _settings = {
    "email_notifications": true,
    "sms_alerts": true,
    "push_notifications": true,
    "system_alert_sounds": false
  };

  // Selection for bulk actions
  final Set<String> _selectedIds = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAlertsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAlertsData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final queryParams = {
        "page": _currentPage,
        "page_size": _pageSize,
        if (_searchQuery.isNotEmpty) "search": _searchQuery,
        if (_selectedCategory != "All Categories") "category": _selectedCategory,
        if (_selectedTab != "All Alerts") "priority": _selectedTab,
        if (_selectedStatus != "All Status") "status": _selectedStatus,
      };

      final res = await ApiService().get('/admin/system-alerts', query: queryParams, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (!mounted) return;
        setState(() {
          _alerts = data['alerts'] ?? [];
          _totalAlerts = data['total'] ?? 0;
          _stats = data['stats'] ?? _stats;
          _breakdown = data['breakdown'] ?? _breakdown;
          _settings = data['settings'] ?? _settings;
        });
      }
    } catch (e) {
      debugPrint("Error fetching system alerts: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSettings(String key, bool value) async {
    if (!mounted) return;
    setState(() {
      _settings[key] = value;
    });
    try {
      if (kIsWeb && key == 'push_notifications' && value) {
        html.Notification.requestPermission().then((permission) {
          if (permission == 'granted') {
            html.Notification('EduSHAMIIT System Alerts', body: 'Browser notifications have been enabled successfully!');
          }
        });
      }
      await ApiService().put('/admin/system-alerts/settings/update', {
        "email_notifications": _settings["email_notifications"] ?? true,
        "sms_alerts": _settings["sms_alerts"] ?? false,
        "push_notifications": _settings["push_notifications"] ?? true,
        "system_alert_sounds": _settings["system_alert_sounds"] ?? false
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notification settings updated!"),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint("Error updating settings: $e");
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      final res = await ApiService().delete('/admin/system-alerts/$alertId');
      if (res['success'] == true) {
        _fetchAlertsData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alert deleted successfully."), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      debugPrint("Error deleting alert: $e");
    }
  }

  Future<void> _toggleAlertRead(Map<String, dynamic> alert, {bool? forceValue}) async {
    final originalIsRead = alert['is_read'] ?? false;
    final newIsRead = forceValue ?? !originalIsRead;
    if (originalIsRead == newIsRead) return;

    // 1. Optimistic local update
    setState(() {
      alert['is_read'] = newIsRead;
      final int currentUnread = _stats['unread_alerts'] ?? 0;
      if (newIsRead) {
        _stats['unread_alerts'] = (currentUnread - 1).clamp(0, 999999);
      } else {
        _stats['unread_alerts'] = currentUnread + 1;
      }
    });

    try {
      // 2. Background API call
      final res = await ApiService().put('/admin/system-alerts/${alert['id']}', {
        "is_read": newIsRead
      });
      if (res['success'] != true) {
        // Revert on failure
        setState(() {
          alert['is_read'] = originalIsRead;
          final int currentUnread = _stats['unread_alerts'] ?? 0;
          if (newIsRead) {
            _stats['unread_alerts'] = currentUnread + 1;
          } else {
            _stats['unread_alerts'] = (currentUnread - 1).clamp(0, 999999);
          }
        });
      }
    } catch (e) {
      debugPrint("Error toggling read state: $e");
      // Revert on error
      setState(() {
        alert['is_read'] = originalIsRead;
        final int currentUnread = _stats['unread_alerts'] ?? 0;
        if (newIsRead) {
          _stats['unread_alerts'] = currentUnread + 1;
        } else {
          _stats['unread_alerts'] = (currentUnread - 1).clamp(0, 999999);
        }
      });
    }
  }

  Future<void> _bulkAction(String action) async {
    if (_selectedIds.isEmpty) return;
    try {
      final res = await ApiService().post('/admin/system-alerts/bulk-update', {
        "ids": _selectedIds.toList(),
        "action": action
      });
      if (res['success'] == true) {
        setState(() {
          _selectedIds.clear();
        });
        _fetchAlertsData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bulk action '$action' completed successfully."),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error on bulk action: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar Spacer is handled by Router Shell layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  _buildMetricsGrid(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main List Section
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFiltersSection(),
                            const SizedBox(height: 16),
                            _buildAlertsTableSection(),
                          ],
                        ),
                      ),
                      // Right Details Sidebar (only visible on Desktop screens)
                      if (isDesktop) ...[
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDonutChartCard(),
                              const SizedBox(height: 20),
                              _buildQuickFiltersCard(),
                              const SizedBox(height: 20),
                              _buildNotificationSettingsCard(),
                              const SizedBox(height: 20),
                              _buildHelpCard(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts & Notifications',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'View and manage all system alerts and notifications in one place.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showCreateAlertDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('Create New Alert', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.count(
          crossAxisCount: crossCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          childAspectRatio: crossCount == 2 ? 1.8 : 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildMetricCard(
              title: 'Total Alerts',
              value: '${_stats['total_alerts'] ?? 0}',
              subtitle: 'All time alerts',
              color: const Color(0xFF8B5CF6),
              icon: Icons.notifications_none_outlined,
            ),
            _buildMetricCard(
              title: 'Unread Alerts',
              value: '${_stats['unread_alerts'] ?? 0}',
              subtitle: 'Require attention',
              color: const Color(0xFF3B82F6),
              icon: Icons.mark_email_unread_outlined,
            ),
            _buildMetricCard(
              title: 'Critical Alerts',
              value: '${_stats['critical_alerts'] ?? 0}',
              subtitle: 'High priority issues',
              color: const Color(0xFFEF4444),
              icon: Icons.error_outline_rounded,
            ),
            _buildMetricCard(
              title: 'Resolved Alerts',
              value: '${_stats['resolved_alerts'] ?? 0}',
              subtitle: 'Successfully resolved',
              color: const Color(0xFF10B981),
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    final tabs = ["All Alerts", "Unread", "Critical", "Warning", "Info", "Resolved"];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tabs
        Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
            final isSelected = _selectedTab == tab;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = tab;
                  _currentPage = 1;
                });
                _fetchAlertsData();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF4F46E5) : (_isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Dropdowns & Search
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Dropdown
            _buildDropdownFilter(
              value: _selectedCategory,
              items: ["All Categories", "Institutions", "Users", "System", "Examinations", "Payments"],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                    _currentPage = 1;
                  });
                  _fetchAlertsData();
                }
              },
            ),
            const SizedBox(width: 8),
            // Status Dropdown
            _buildDropdownFilter(
              value: _selectedStatus,
              items: ["All Status", "New", "In Progress", "Resolved"],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedStatus = val;
                    _currentPage = 1;
                  });
                  _fetchAlertsData();
                }
              },
            ),
            const SizedBox(width: 12),
            // Search Input
            SizedBox(
              width: 200,
              height: 36,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search alerts...',
                  prefixIcon: const Icon(Icons.search, size: 14),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  fillColor: _cardBg,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                ),
                onChanged: (val) {
                  if (val.isEmpty && _searchQuery.isNotEmpty) {
                    setState(() {
                      _searchQuery = "";
                      _currentPage = 1;
                    });
                    _fetchAlertsData();
                  }
                },
                onSubmitted: (val) {
                  setState(() {
                    _searchQuery = val;
                    _currentPage = 1;
                  });
                  _fetchAlertsData();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: TextStyle(fontSize: 12, color: _isDark ? Colors.white : Colors.black87),
          dropdownColor: _cardBg,
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAlertsTableSection() {
    if (_isLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bulk Actions bar if anything selected
          if (_selectedIds.isNotEmpty) _buildBulkActionBar(),
          
          // Table Headers
          _buildTableHeader(),
          const Divider(height: 1),
          
          // Table Rows
          if (_alerts.isEmpty)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: const Text('No alerts found matching filters.', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertRow(alert);
              },
            ),
            
          const Divider(height: 1),
          // Pagination Footer
          _buildTableFooter(),
        ],
      ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} items selected',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 12),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.mark_email_read_outlined, size: 14),
            label: const Text('Mark Read', style: TextStyle(fontSize: 11)),
            onPressed: () => _bulkAction('read'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.mark_email_unread_outlined, size: 14),
            label: const Text('Mark Unread', style: TextStyle(fontSize: 11)),
            onPressed: () => _bulkAction('unread'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 14),
            label: const Text('Resolve', style: TextStyle(fontSize: 11)),
            onPressed: () => _bulkAction('resolve'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            label: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red)),
            onPressed: () => _bulkAction('delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Checkbox(
            value: _alerts.isNotEmpty && _selectedIds.length == _alerts.length,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.addAll(_alerts.map((a) => a['id'].toString()));
                } else {
                  _selectedIds.clear();
                }
              });
            },
          ),
          const SizedBox(width: 12),
          const Expanded(flex: 3, child: Text('Alert Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const Expanded(flex: 2, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const Expanded(flex: 1, child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const Expanded(flex: 2, child: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          const SizedBox(width: 80, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildAlertRow(Map<String, dynamic> alert) {
    final isSelected = _selectedIds.contains(alert['id']);
    final isUnread = !(alert['is_read'] ?? false);

    // ── Category icon & color ──────────────────────────────────────────
    IconData categoryIcon = Icons.info_outline;
    Color categoryColor = const Color(0xFF3B82F6);
    final cat = alert['category'].toString().toLowerCase();
    if (cat.contains('inst')) {
      categoryIcon = Icons.domain_outlined;
      categoryColor = const Color(0xFFEF4444);
    } else if (cat.contains('user')) {
      categoryIcon = Icons.people_outline_rounded;
      categoryColor = const Color(0xFFF59E0B);
    } else if (cat.contains('sys')) {
      categoryIcon = Icons.dns_outlined;
      categoryColor = const Color(0xFF3B82F6);
    } else if (cat.contains('exam')) {
      categoryIcon = Icons.school_outlined;
      categoryColor = const Color(0xFF8B5CF6);
    } else if (cat.contains('pay')) {
      categoryIcon = Icons.currency_rupee_rounded;
      categoryColor = const Color(0xFF10B981);
    }

    // ── Priority chip — theme-aware ────────────────────────────────────
    Color priorityBg;
    Color priorityText;
    final priority = alert['priority'].toString();
    if (priority == 'Critical') {
      priorityBg = _isDark ? const Color(0xFFEF4444).withValues(alpha: 0.18) : const Color(0xFFFEE2E2);
      priorityText = _isDark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444);
    } else if (priority == 'High') {
      priorityBg = _isDark ? const Color(0xFFF97316).withValues(alpha: 0.18) : const Color(0xFFFFEDD5);
      priorityText = _isDark ? const Color(0xFFFDBA74) : const Color(0xFFF97316);
    } else if (priority == 'Warning') {
      priorityBg = _isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.18) : const Color(0xFFFEF3C7);
      priorityText = _isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
    } else {
      priorityBg = _isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.18) : const Color(0xFFDBEAFE);
      priorityText = _isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
    }

    // ── Status chip — theme-aware ──────────────────────────────────────
    Color statusBg;
    Color statusText;
    final status = alert['status'].toString();
    if (status == 'New') {
      statusBg = _isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.22) : const Color(0xFFEEF2FF);
      statusText = _isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
    } else if (status == 'In Progress') {
      statusBg = _isDark ? const Color(0xFF0284C7).withValues(alpha: 0.22) : const Color(0xFFE0F2FE);
      statusText = _isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7);
    } else if (status == 'Resolved') {
      statusBg = _isDark ? const Color(0xFF10B981).withValues(alpha: 0.18) : const Color(0xFFD1FAE5);
      statusText = _isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    } else {
      statusBg = _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9);
      statusText = _isDark ? Colors.white54 : const Color(0xFF64748B);
    }

    // ── Row background & left accent ───────────────────────────────────
    //  Unread:  strong indigo-tinted row  +  3px indigo left border
    //  Read:    transparent row           +  no border (3px transparent)
    final Color rowBg = isUnread
        ? (_isDark
            ? const Color(0xFF4F46E5).withValues(alpha: 0.10)
            : const Color(0xFFEEF2FF))
        : Colors.transparent;
    final Color accentBorder = isUnread
        ? const Color(0xFF4F46E5)
        : Colors.transparent;

    // ── Date formatting ────────────────────────────────────────────────
    final createdAt = alert['created_at'] != null
        ? DateTime.parse(alert['created_at'])
        : DateTime.now();
    final localTime = createdAt.toLocal();
    final formattedTime = DateFormat('MMM dd, yyyy hh:mm a').format(localTime);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (_isDark
                ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                : const Color(0xFFE0E7FF))
            : rowBg,
        border: Border(
          left: BorderSide(color: accentBorder, width: 3),
          bottom: BorderSide(
            color: _isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            activeColor: const Color(0xFF4F46E5),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(alert['id']);
                } else {
                  _selectedIds.remove(alert['id']);
                }
              });
            },
          ),
          const SizedBox(width: 8),

          // ── Alert Title + description ──────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Category icon with colored container
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: _isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(categoryIcon, size: 15, color: categoryColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert['title'] ?? 'Title',
                              style: GoogleFonts.inter(
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                                color: isUnread
                                    ? (_isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3))
                                    : _textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[  
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alert['description'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: _isDark
                              ? (isUnread ? Colors.white38 : Colors.white24)
                              : (isUnread ? const Color(0xFF6366F1) : Colors.grey),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Category badge ─────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: _isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: _isDark ? 0.30 : 0.20),
                    ),
                  ),
                  child: Text(
                    alert['category'] ?? 'General',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: categoryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Priority badge ─────────────────────────────────────────
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: priorityText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Created At ─────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Text(
              formattedTime,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isUnread
                    ? (_isDark ? Colors.white54 : const Color(0xFF4F46E5).withValues(alpha: 0.7))
                    : (_isDark ? Colors.white30 : Colors.grey),
                fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),

          // ── Status badge ───────────────────────────────────────────
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: statusText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Actions ────────────────────────────────────────────────
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Eye icon: filled + indigo = unread, outline + grey = read
                Tooltip(
                  message: isUnread ? 'Mark as read' : 'View details',
                  child: InkWell(
                    onTap: () {
                      _showViewAlertDialog(alert);
                      if (isUnread) _toggleAlertRead(alert, forceValue: true);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isUnread
                            ? const Color(0xFF4F46E5).withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isUnread ? Icons.visibility_rounded : Icons.visibility_outlined,
                        size: 16,
                        color: isUnread
                            ? const Color(0xFF6366F1)
                            : (_isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: _isDark ? Colors.white54 : Colors.black54,
                  ),
                  color: _isDark ? const Color(0xFF1E293B) : Colors.white,
                  onSelected: (val) {
                    if (val == 'toggle_read') {
                      _toggleAlertRead(alert);
                    } else if (val == 'edit') {
                      _showEditAlertDialog(alert);
                    } else if (val == 'delete') {
                      _deleteAlert(alert['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_read',
                      child: Row(
                        children: [
                          Icon(
                            isUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                            size: 14,
                            color: const Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isUnread ? 'Mark as Read' : 'Mark as Unread',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Edit / Resolve', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
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
    );
  }


  Widget _buildTableFooter() {
    final int totalPages = (_totalAlerts / _pageSize).ceil();
    final int startItem = ((_currentPage - 1) * _pageSize) + 1;
    final int endItem = _currentPage * _pageSize > _totalAlerts ? _totalAlerts : _currentPage * _pageSize;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing $startItem to $endItem of $_totalAlerts alerts',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    style: TextStyle(fontSize: 10, color: _isDark ? Colors.white : Colors.black87),
                    dropdownColor: _cardBg,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                        _fetchAlertsData();
                      }
                    },
                    items: [5, 10, 20, 50, 100].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size / page'),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 16),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchAlertsData();
                      }
                    : null,
              ),
              const SizedBox(width: 4),
              // Page Numbers
              Row(
                children: List.generate(totalPages == 0 ? 1 : totalPages, (index) {
                  final pageNum = index + 1;
                  final isCurrent = _currentPage == pageNum;
                  return InkWell(
                    onTap: () {
                      setState(() => _currentPage = pageNum);
                      _fetchAlertsData();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF4F46E5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : (_isDark ? Colors.white60 : Colors.black87),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 16),
                onPressed: _currentPage < totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchAlertsData();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alert Summary',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: AlertsDonutPainter(
                    breakdown: _breakdown,
                    isDark: _isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_stats['total_alerts'] ?? 0}',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                        ),
                        const Text('Total', style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildDonutLegendRow('Critical', _breakdown['critical'] ?? 0, const Color(0xFFEF4444)),
                    const SizedBox(height: 4),
                    _buildDonutLegendRow('High', _breakdown['high'] ?? 0, const Color(0xFFF59E0B)),
                    const SizedBox(height: 4),
                    _buildDonutLegendRow('Warning', _breakdown['warning'] ?? 0, const Color(0xFFD97706)),
                    const SizedBox(height: 4),
                    _buildDonutLegendRow('Info', _breakdown['info'] ?? 0, const Color(0xFF3B82F6)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendRow(String name, int val, Color color) {
    final total = _stats['total_alerts'] != 0 ? _stats['total_alerts'] : 1;
    final pct = ((val / total) * 100).toStringAsFixed(0);

    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 10, color: Colors.grey))),
        Text('$val ($pct%)', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildQuickFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Filters',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          _buildQuickFilterRow('New Alerts', _stats['unread_alerts'] ?? 0, () {
            setState(() {
              _selectedTab = "Unread";
              _currentPage = 1;
            });
            _fetchAlertsData();
          }),
          _buildQuickFilterRow('In Progress', _stats['in_progress_alerts'] ?? 0, () {
            setState(() {
              _selectedStatus = "In Progress";
              _currentPage = 1;
            });
            _fetchAlertsData();
          }),
          _buildQuickFilterRow('Resolved Today', _stats['resolved_today_alerts'] ?? 0, () {
            setState(() {
              _selectedTab = "Resolved";
              _currentPage = 1;
            });
            _fetchAlertsData();
          }),
          _buildQuickFilterRow('Critical Alerts', _stats['critical_alerts'] ?? 0, () {
            setState(() {
              _selectedTab = "Critical";
              _currentPage = 1;
            });
            _fetchAlertsData();
          }),
        ],
      ),
    );
  }

  Widget _buildQuickFilterRow(String label, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notification Settings',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 12),
          _buildSettingsSwitchRow('Email Notifications', 'email_notifications'),
          _buildSettingsSwitchRow('SMS Notifications', 'sms_alerts'),
          _buildSettingsSwitchRow('Browser Notifications', 'push_notifications'),
          _buildSettingsSwitchRow('System Alert Sounds', 'system_alert_sounds'),
        ],
      ),
    );
  }

  Widget _buildSettingsSwitchRow(String label, String settingsKey) {
    final isEnabled = _settings[settingsKey] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Switch(
            value: isEnabled,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) => _updateSettings(settingsKey, val),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 8),
              Text(
                'Need Help?',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'If you need help with alerts or notifications, our support team is here.',
            style: TextStyle(fontSize: 11, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size.fromHeight(36),
            ),
            onPressed: () => context.go('/admin/support'),
            child: const Text('Contact Support', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // Create / Read / Update Dialogs
  // ===========================================================

  void _showCreateAlertDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String category = "System";
    String priority = "Critical";
    String status = "New";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              title: Text('Create New Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title', hintText: 'Enter alert title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Enter description text'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Category',
                        value: category,
                        items: ["Institutions", "Users", "System", "Examinations", "Payments"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Priority',
                        value: priority,
                        items: ["Critical", "High", "Warning", "Info"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => priority = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Status',
                        value: status,
                        items: ["New", "In Progress", "Resolved"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    try {
                      final res = await ApiService().post('/admin/system-alerts', {
                        "title": titleController.text,
                        "description": descController.text,
                        "category": category,
                        "priority": priority,
                        "status": status
                      });
                      if (res['success'] == true) {
                        Navigator.pop(context);
                        _fetchAlertsData();
                      }
                    } catch (e) {
                      debugPrint("Error creating alert: $e");
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showViewAlertDialog(Map<String, dynamic> alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBg,
          title: Text(alert['title'] ?? 'Alert Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text(alert['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Category:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(alert['category'] ?? 'System', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Priority:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(alert['priority'] ?? 'Info', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(alert['status'] ?? 'New', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Read:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(alert['is_read'] == true ? 'Read' : 'Unread', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEditAlertDialog(Map<String, dynamic> alert) {
    final titleController = TextEditingController(text: alert['title']);
    final descController = TextEditingController(text: alert['description']);
    String category = alert['category'] ?? "System";
    String priority = alert['priority'] ?? "Critical";
    String status = alert['status'] ?? "New";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardBg,
              title: Text('Edit / Resolve Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Category',
                        value: category,
                        items: ["Institutions", "Users", "System", "Examinations", "Payments"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Priority',
                        value: priority,
                        items: ["Critical", "High", "Warning", "Info"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => priority = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDialogDropdown(
                        label: 'Status',
                        value: status,
                        items: ["New", "In Progress", "Resolved"],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  onPressed: () async {
                    try {
                      final res = await ApiService().put('/admin/system-alerts/${alert['id']}', {
                        "title": titleController.text,
                        "description": descController.text,
                        "category": category,
                        "priority": priority,
                        "status": status,
                        "is_read": status == "Resolved" ? true : alert['is_read']
                      });
                      if (res['success'] == true) {
                        Navigator.pop(context);
                        _fetchAlertsData();
                      }
                    } catch (e) {
                      debugPrint("Error updating alert: $e");
                    }
                  },
                  child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
              dropdownColor: _cardBg,
              onChanged: onChanged,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class AlertsDonutPainter extends CustomPainter {
  final Map<String, dynamic> breakdown;
  final bool isDark;

  AlertsDonutPainter({required this.breakdown, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double critical = (breakdown['critical'] ?? 0).toDouble();
    final double high = (breakdown['high'] ?? 0).toDouble();
    final double warning = (breakdown['warning'] ?? 0).toDouble();
    final double info = (breakdown['info'] ?? 0).toDouble();

    final double total = critical + high + warning + info;
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    double startAngle = -3.14159 / 2; // Start from top 12 o'clock

    // Critical (Red)
    if (critical > 0) {
      paint.color = const Color(0xFFEF4444);
      final sweepAngle = (critical / total) * 2 * 3.14159;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // High (Orange)
    if (high > 0) {
      paint.color = const Color(0xFFF59E0B);
      final sweepAngle = (high / total) * 2 * 3.14159;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Warning (Amber)
    if (warning > 0) {
      paint.color = const Color(0xFFD97706);
      final sweepAngle = (warning / total) * 2 * 3.14159;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }

    // Info (Blue)
    if (info > 0) {
      paint.color = const Color(0xFF3B82F6);
      final sweepAngle = (info / total) * 2 * 3.14159;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
