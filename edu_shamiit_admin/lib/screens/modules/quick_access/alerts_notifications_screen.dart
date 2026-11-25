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
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _inputBg => _isDark ? const Color(0xFF0A0D1A) : const Color(0xFFF8FAFC);

  static const _accent = Color(0xFF4F46E5);
  static const _green = Color(0xFF10B981);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  String _normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "System";
    final l = raw.trim().toLowerCase();
    if (l.contains("inst")) return "Institutions";
    if (l.contains("user")) return "Users";
    if (l.contains("exam")) return "Examinations";
    if (l.contains("pay")) return "Payments";
    if (l.contains("sys")) return "System";
    return "System";
  }

  String _displayCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "System";
    final l = raw.trim().toLowerCase();
    if (l == "system_alert" || (l.contains("sys") && l.contains("alert"))) return "System Alert";
    return _normalizeCategory(raw);
  }

  String _normalizePriority(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "Info";
    final l = raw.trim().toLowerCase();
    if (l == "critical") return "Critical";
    if (l == "high") return "High";
    if (l == "warning" || l == "warn") return "Warning";
    if (l == "normal" || l == "info" || l == "low") return "Info";
    return "Info";
  }

  String _displayPriority(String? raw) {
    if (raw == null || raw.trim().isEmpty) return "Info";
    final l = raw.trim().toLowerCase();
    if (l == "normal") return "Normal";
    if (l == "critical") return "Critical";
    if (l == "high") return "High";
    if (l == "warning") return "Warning";
    return "Info";
  }

  String _normalizeStatus(String? raw, [bool? isRead]) {
    if (raw != null && raw.trim().isNotEmpty) {
      final l = raw.trim().toLowerCase();
      if (l == "resolved" || l == "completed") return "Resolved";
      if (l == "in progress" || l == "in_progress") return "In Progress";
      if (l == "new" || l == "unread" || l == "active") return "New";
    }
    return "New";
  }

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
    "total_alerts": 0,
    "unread_alerts": 0,
    "critical_alerts": 0,
    "high_alerts": 0,
    "warning_alerts": 0,
    "info_alerts": 0,
    "resolved_alerts": 0,
    "in_progress_alerts": 0,
    "resolved_today_alerts": 0,
  };
  
  Map<String, dynamic> _breakdown = {
    "critical": 0,
    "high": 0,
    "warning": 0,
    "info": 0
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
          if (data['breakdown'] != null) {
            _breakdown = Map<String, dynamic>.from(data['breakdown']);
          } else {
            int crit = 0, high = 0, warn = 0, info = 0;
            for (var a in _alerts) {
              final p = (a['priority'] ?? '').toString().toLowerCase();
              if (p == 'critical') {
                crit++;
              } else if (p == 'high') {
                high++;
              } else if (p == 'warning') {
                warn++;
              } else {
                info++;
              }
            }
            _breakdown = {
              "critical": crit,
              "high": high,
              "warning": warn,
              "info": info
            };
          }
          _settings = data['settings'] ?? _settings;
        });
      }
    } catch (e) {
      debugPrint("Error fetching system alerts: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        final width = constraints.maxWidth;
        final int cols;
        const double spacing = 12.0;
        if (width >= 1100) {
          cols = 4;
        } else if (width >= 600) {
          cols = 2;
        } else {
          cols = 1;
        }
        final double totalSpacing = (cols - 1) * spacing;
        final double cardWidth = ((width - totalSpacing) / cols).floorToDouble();

        final cards = [
          _buildMetricCard(
            title: 'Total Alerts',
            value: '${_stats['total_alerts'] ?? 0}',
            subtitle: 'All time alerts',
            color: const Color(0xFF8B5CF6),
            icon: Icons.notifications_none_outlined,
            isSelected: _selectedTab == 'All Alerts' && _selectedStatus == 'All Status',
            onTap: () {
              setState(() {
                _selectedTab = 'All Alerts';
                _selectedStatus = 'All Status';
                _currentPage = 1;
              });
              _fetchAlertsData();
            },
          ),
          _buildMetricCard(
            title: 'Unread Alerts',
            value: '${_stats['unread_alerts'] ?? 0}',
            subtitle: 'Require attention',
            color: const Color(0xFF3B82F6),
            icon: Icons.mark_email_unread_outlined,
            isSelected: _selectedTab == 'Unread',
            onTap: () {
              setState(() {
                _selectedTab = 'Unread';
                _selectedStatus = 'All Status';
                _currentPage = 1;
              });
              _fetchAlertsData();
            },
          ),
          _buildMetricCard(
            title: 'Critical Alerts',
            value: '${_stats['critical_alerts'] ?? 0}',
            subtitle: 'High priority issues',
            color: const Color(0xFFEF4444),
            icon: Icons.error_outline_rounded,
            isSelected: _selectedTab == 'Critical',
            onTap: () {
              setState(() {
                _selectedTab = 'Critical';
                _selectedStatus = 'All Status';
                _currentPage = 1;
              });
              _fetchAlertsData();
            },
          ),
          _buildMetricCard(
            title: 'Resolved Alerts',
            value: '${_stats['resolved_alerts'] ?? 0}',
            subtitle: 'Successfully resolved',
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
            isSelected: _selectedTab == 'Resolved',
            onTap: () {
              setState(() {
                _selectedTab = 'Resolved';
                _selectedStatus = 'All Status';
                _currentPage = 1;
              });
              _fetchAlertsData();
            },
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
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
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: color.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: _isDark ? 0.12 : 0.06)
                : _cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : _borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isSelected ? 0.20 : 0.10),
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
                      style: GoogleFonts.inter(fontSize: 10, color: _textSecondary),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    final tabs = [
      {'label': 'All Alerts', 'icon': Icons.notifications_none_rounded, 'count': _stats['total_alerts']},
      {'label': 'Unread', 'icon': Icons.mark_email_unread_outlined, 'count': _stats['unread_alerts']},
      {'label': 'Critical', 'icon': Icons.error_outline_rounded, 'count': _stats['critical_alerts']},
      {'label': 'Warning', 'icon': Icons.warning_amber_rounded, 'count': _stats['warning_alerts']},
      {'label': 'Info', 'icon': Icons.info_outline_rounded, 'count': _stats['info_alerts']},
      {'label': 'Resolved', 'icon': Icons.check_circle_outline_rounded, 'count': _stats['resolved_alerts']},
    ];

    final bool hasActiveFilters = _selectedTab != "All Alerts" ||
        _selectedCategory != "All Categories" ||
        _selectedStatus != "All Status" ||
        _searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Scope Segmented Pills
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: _borderColor),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: tabs.map((tab) {
                          final label = tab['label'] as String;
                          final icon = tab['icon'] as IconData;
                          final count = tab['count'];
                          final isSelected = _selectedTab == label;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTab = label;
                                _currentPage = 1;
                              });
                              _fetchAlertsData();
                            },
                            borderRadius: BorderRadius.circular(7),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 13,
                                    color: isSelected ? Colors.white : _textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : (_isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                    ),
                                  ),
                                  if (count != null && count > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : (_isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : _textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Dropdowns & Search Toolbar
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Category Dropdown
                      _buildDropdownFilter(
                        value: _selectedCategory,
                        width: 145,
                        items: const ["All Categories", "Institutions", "Users", "System", "Examinations", "Payments"],
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

                      // Status Dropdown
                      _buildDropdownFilter(
                        value: _selectedStatus,
                        width: 130,
                        items: const ["All Status", "New", "In Progress", "Resolved"],
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

                      // Search Input
                      SizedBox(
                        width: 190,
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 12, color: _textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Search alerts...',
                            hintStyle: TextStyle(fontSize: 12, color: _textSecondary),
                            prefixIcon: Icon(Icons.search, size: 14, color: _textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? InkWell(
                                    onTap: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = "";
                                        _currentPage = 1;
                                      });
                                      _fetchAlertsData();
                                    },
                                    child: Icon(Icons.close_rounded, size: 14, color: _textSecondary),
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            fillColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _borderColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.2)),
                          ),
                          onChanged: (val) {
                            setState(() {});
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
                              _searchQuery = val.trim();
                              _currentPage = 1;
                            });
                            _fetchAlertsData();
                          },
                        ),
                      ),

                      // Reset Filters Button
                      if (hasActiveFilters)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTab = "All Alerts";
                              _selectedCategory = "All Categories";
                              _selectedStatus = "All Status";
                              _searchQuery = "";
                              _searchController.clear();
                              _currentPage = 1;
                            });
                            _fetchAlertsData();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.clear_rounded, size: 13, color: Colors.redAccent),
                                SizedBox(width: 4),
                                Text(
                                  'Reset',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double width = 145,
  }) {
    final uniqueItems = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && !uniqueItems.contains(trimmed)) {
        uniqueItems.add(trimmed);
      }
    }
    final effectiveValue = uniqueItems.contains(value.trim())
        ? value.trim()
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Container(
      width: width,
      height: 36,
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: effectiveValue,
          width: width,
          isExpanded: false,
          compact: true,
          isDense: true,
          itemHeight: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          dropdownColor: _cardBg,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            fontWeight: FontWeight.w500,
          ),
          items: uniqueItems.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
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

    final tableBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedIds.isNotEmpty) _buildBulkActionBar(),
        _buildTableHeader(),
        const Divider(height: 1),
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
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 800,
                    child: tableBody,
                  ),
                );
              }
              return tableBody;
            },
          ),
          const Divider(height: 1),
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
          SizedBox(
            width: 48,
            child: Center(
              child: Checkbox(
                value: _alerts.isNotEmpty && _selectedIds.length == _alerts.length,
                activeColor: const Color(0xFF4F46E5),
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
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Row(
              children: [
                Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: Text('Alert Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              ],
            ),
          ),
          const SizedBox(width: 88, child: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        ],
      ),
    );
  }

  Widget _buildAlertRow(Map<String, dynamic> alert) {
    final isSelected = _selectedIds.contains(alert['id']);
    final isUnread = !(alert['is_read'] ?? false);
    final displayCategory = _displayCategory(alert['category']?.toString());
    final displayPriority = _displayPriority(alert['priority']?.toString());
    final priority = _normalizePriority(alert['priority']?.toString());
    final status = _normalizeStatus(alert['status']?.toString(), alert['is_read'] == true);
    final alertDesc = (alert['description'] ?? alert['message'] ?? '').toString().trim();

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            child: Center(
              child: Checkbox(
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
            ),
          ),
          const SizedBox(width: 8),

          // ── Clickable Alert Row Content (tapping opens details & auto-marks as read) ──
          Expanded(
            child: InkWell(
              onTap: () => _showViewAlertDialog(alert),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Alert Title + description ──────────────────────────────
                    Expanded(
                      flex: 3,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: _isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(categoryIcon, size: 16, color: categoryColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        alert['title'] ?? 'Title',
                                        style: GoogleFonts.inter(
                                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                          fontSize: 13,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                if (alertDesc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    alertDesc,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _isDark
                                          ? (isUnread ? Colors.white54 : Colors.white38)
                                          : (isUnread ? const Color(0xFF6366F1) : Colors.grey.shade600),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Category badge (CENTER ALIGNED) ─────────────────────────
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: _isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: categoryColor.withValues(alpha: _isDark ? 0.30 : 0.20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon, size: 12, color: categoryColor),
                              const SizedBox(width: 5),
                              Text(
                                displayCategory,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: categoryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Priority badge (CENTER ALIGNED) ─────────────────────────
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: priorityText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                displayPriority,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: priorityText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Created At (CENTER ALIGNED) ─────────────────────────────
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text(
                          formattedTime,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isUnread
                                ? (_isDark ? Colors.white70 : const Color(0xFF4F46E5))
                                : (_isDark ? Colors.white54 : Colors.grey.shade700),
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),

                    // ── Status badge (CENTER ALIGNED) ───────────────────────────
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                status,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: statusText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Actions (CENTER ALIGNED) ────────────────────────────────
          SizedBox(
            width: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Tooltip(
                  message: 'View details',
                  child: InkWell(
                    onTap: () {
                      _showViewAlertDialog(alert);
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
                        Icons.visibility_outlined,
                        size: 16,
                        color: isUnread
                            ? const Color(0xFF6366F1)
                            : (_isDark ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: _isDark ? Colors.white60 : Colors.black54,
                  ),
                  color: _isDark ? const Color(0xFF1E293B) : Colors.white,
                  onSelected: (val) {
                    if (val == 'view') {
                      _showViewAlertDialog(alert);
                    } else if (val == 'toggle_read') {
                      _toggleAlertRead(alert);
                    } else if (val == 'edit') {
                      _showEditAlertDialog(alert);
                    } else if (val == 'delete') {
                      _deleteAlert(alert['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF3B82F6)),
                          SizedBox(width: 8),
                          Text('View Details', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
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
    final int startItem = _totalAlerts == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final int endItem = _currentPage * _pageSize > _totalAlerts ? _totalAlerts : _currentPage * _pageSize;

    final List<int> visiblePages = [];
    final effectiveTotalPages = totalPages == 0 ? 1 : totalPages;
    if (effectiveTotalPages <= 5) {
      visiblePages.addAll(List.generate(effectiveTotalPages, (i) => i + 1));
    } else {
      int start = (_currentPage - 2).clamp(1, effectiveTotalPages - 4);
      visiblePages.addAll(List.generate(5, (i) => start + i));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;
        final infoRow = Row(
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
                child: AppSearchableDropdown<int>.fromMenuItems(
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
        );

        final paginationControls = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 16),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _fetchAlertsData();
                      }
                    : null,
              ),
              ...visiblePages.map((pageNum) {
                final isCurrent = _currentPage == pageNum;
                return InkWell(
                  onTap: () {
                    setState(() => _currentPage = pageNum);
                    _fetchAlertsData();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
              if (effectiveTotalPages > 5 && !visiblePages.contains(effectiveTotalPages)) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2),
                  child: Text('...', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _currentPage = effectiveTotalPages);
                    _fetchAlertsData();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _currentPage == effectiveTotalPages ? const Color(0xFF4F46E5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$effectiveTotalPages',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _currentPage == effectiveTotalPages ? Colors.white : (_isDark ? Colors.white60 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 16),
                onPressed: _currentPage < effectiveTotalPages
                    ? () {
                        setState(() => _currentPage++);
                        _fetchAlertsData();
                      }
                    : null,
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoRow,
                    const SizedBox(height: 8),
                    Center(child: paginationControls),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    infoRow,
                    paginationControls,
                  ],
                ),
        );
      },
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
    final int total = ((_stats['total_alerts'] ?? 0) as num).toInt();
    final String pct = total > 0 ? ((val / total) * 100).toStringAsFixed(0) : '0';

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
  // Create / Read / Update Dialogs (Matching Driver Management Style)
  // ===========================================================

  void _showCreateAlertDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String category = "System";
    String priority = "Critical";
    String status = "New";
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                      color: _isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_alert_rounded, color: _accent, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create New Alert',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Broadcast a new system alert across the platform',
                                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20, color: _textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),

                    // ── Body ──
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: titleController,
                              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Alert Title *',
                                hintText: 'e.g. Scheduled Maintenance or Examination Update',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary.withValues(alpha: 0.6)),
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                prefixIcon: const Icon(Icons.campaign_outlined, color: _accent, size: 20),
                                filled: true,
                                fillColor: _inputBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: descController,
                              maxLines: 3,
                              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Description / Message',
                                hintText: 'Enter detailed notification message for administrators and staff...',
                                hintStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary.withValues(alpha: 0.6)),
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                prefixIcon: const Icon(Icons.notes_rounded, color: _accent, size: 20),
                                filled: true,
                                fillColor: _inputBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogDropdown(
                                    label: 'Category',
                                    value: category,
                                    icon: Icons.category_outlined,
                                    items: ["System", "Institutions", "Users", "Examinations", "Payments"],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => category = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildDialogDropdown(
                                    label: 'Priority Level',
                                    value: priority,
                                    icon: Icons.flag_outlined,
                                    items: ["Critical", "High", "Warning", "Info"],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => priority = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDialogDropdown(
                              label: 'Initial Status',
                              value: status,
                              icon: Icons.timelapse_rounded,
                              items: ["New", "In Progress", "Resolved"],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => status = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),

                    // ── Footer ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: _isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textSecondary,
                              side: BorderSide(color: _borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Create Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              try {
                                final res = await ApiService().post('/admin/system-alerts', {
                                  "title": titleController.text.trim(),
                                  "description": descController.text.trim(),
                                  "category": category,
                                  "priority": priority,
                                  "status": status,
                                });
                                if (res['success'] == true) {
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  _fetchAlertsData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Alert created successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint("Error creating alert: $e");
                              }
                            },
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
      },
    );
  }

  void _showViewAlertDialog(Map<String, dynamic> alert) {
    // Automatically mark as read if currently unread
    if (!(alert['is_read'] ?? false)) {
      _toggleAlertRead(alert, forceValue: true);
    }
    bool isRead = alert['is_read'] == true;

    final alertDesc = (alert['description'] ?? alert['message'] ?? '').toString().trim();
    final displayCategory = _displayCategory(alert['category']?.toString());
    final displayPriority = _displayPriority(alert['priority']?.toString());
    final priority = _normalizePriority(alert['priority']?.toString());
    final status = _normalizeStatus(alert['status']?.toString(), alert['is_read'] == true);

    final createdAt = alert['created_at'] != null
        ? DateTime.parse(alert['created_at'])
        : DateTime.now();
    final localTime = createdAt.toLocal();
    final formattedTime = DateFormat('MMMM dd, yyyy • hh:mm a').format(localTime);

    // Category styling
    IconData categoryIcon = Icons.info_outline;
    Color categoryColor = _blue;
    final cat = alert['category'].toString().toLowerCase();
    if (cat.contains('inst')) {
      categoryIcon = Icons.domain_outlined;
      categoryColor = _red;
    } else if (cat.contains('user')) {
      categoryIcon = Icons.people_outline_rounded;
      categoryColor = _orange;
    } else if (cat.contains('sys')) {
      categoryIcon = Icons.dns_outlined;
      categoryColor = _blue;
    } else if (cat.contains('exam')) {
      categoryIcon = Icons.school_outlined;
      categoryColor = const Color(0xFF8B5CF6);
    } else if (cat.contains('pay')) {
      categoryIcon = Icons.currency_rupee_rounded;
      categoryColor = _green;
    }

    // Priority styling
    Color priorityColor = _blue;
    if (priority == 'Critical') {
      priorityColor = _red;
    } else if (priority == 'High') {
      priorityColor = const Color(0xFFF97316);
    } else if (priority == 'Warning') {
      priorityColor = _orange;
    }

    // Status styling
    Color statusColor = _accent;
    if (status == 'Resolved') {
      statusColor = _green;
    } else if (status == 'In Progress') {
      statusColor = const Color(0xFF0284C7);
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                        color: _isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(categoryIcon, color: categoryColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert['title'] ?? 'Alert Details',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 20, color: _textSecondary),
                              onPressed: () => Navigator.pop(ctx),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: _borderColor),

                      // ── Body ──
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Message card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.format_quote_rounded, size: 16, color: _accent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ALERT MESSAGE',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textSecondary, letterSpacing: 0.6),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    alertDesc.isNotEmpty ? alertDesc : 'No description provided.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: alertDesc.isNotEmpty ? _textPrimary : _textSecondary,
                                      fontStyle: alertDesc.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Metadata Details
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Column(
                                children: [
                                  _buildDetailRowItem(
                                    icon: Icons.category_outlined,
                                    label: 'Category',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(categoryIcon, size: 12, color: categoryColor),
                                          const SizedBox(width: 5),
                                          Text(displayCategory, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: categoryColor)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(height: 18, color: _borderColor.withValues(alpha: 0.5)),
                                  _buildDetailRowItem(
                                    icon: Icons.flag_outlined,
                                    label: 'Priority Level',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 6, height: 6, decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          Text(displayPriority, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: priorityColor)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(height: 18, color: _borderColor.withValues(alpha: 0.5)),
                                  _buildDetailRowItem(
                                    icon: Icons.timelapse_rounded,
                                    label: 'Current Status',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                                          const SizedBox(width: 6),
                                          Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(height: 18, color: _borderColor.withValues(alpha: 0.5)),
                                  _buildDetailRowItem(
                                    icon: isRead ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
                                    label: 'Delivery Status',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isRead
                                            ? _green.withValues(alpha: 0.12)
                                            : _accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isRead
                                              ? _green.withValues(alpha: 0.25)
                                              : _accent.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isRead ? Icons.check_circle_outline_rounded : Icons.mark_email_unread_outlined,
                                            size: 13,
                                            color: isRead ? _green : _accent,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isRead ? 'Read' : 'Unread (Action Required)',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isRead ? _green : _accent,
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
                      Divider(height: 1, color: _borderColor),

                      // ── Footer ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        color: _isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                final targetState = !isRead;
                                setDialogState(() {
                                  isRead = targetState;
                                });
                                _toggleAlertRead(alert, forceValue: targetState);
                              },
                              icon: Icon(
                                isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                                size: 16,
                                color: isRead ? _accent : _green,
                              ),
                              label: Text(
                                isRead ? 'Mark as Unread' : 'Mark as Read',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isRead ? _accent : _green),
                              ),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.edit_outlined, size: 14),
                                  label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showEditAlertDialog(alert);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _cardBg,
                                    foregroundColor: _textPrimary,
                                    side: BorderSide(color: _borderColor),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRowItem({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        child,
      ],
    );
  }

  void _showEditAlertDialog(Map<String, dynamic> alert) {
    final titleController = TextEditingController(text: alert['title'] ?? '');
    final descController = TextEditingController(text: (alert['description'] ?? alert['message'] ?? '').toString());
    String category = _normalizeCategory(alert['category']?.toString());
    String priority = _normalizePriority(alert['priority']?.toString());
    String status = _normalizeStatus(alert['status']?.toString(), alert['is_read'] == true);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                      color: _isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: Colors.orange, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit / Resolve Alert',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update alert details, priority level, or mark as resolved',
                                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20, color: _textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),

                    // ── Body ──
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: titleController,
                              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Alert Title *',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                prefixIcon: const Icon(Icons.campaign_outlined, color: _accent, size: 20),
                                filled: true,
                                fillColor: _inputBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: descController,
                              maxLines: 3,
                              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Description / Message',
                                labelStyle: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                                prefixIcon: const Icon(Icons.notes_rounded, color: _accent, size: 20),
                                filled: true,
                                fillColor: _inputBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogDropdown(
                                    label: 'Category',
                                    value: category,
                                    icon: Icons.category_outlined,
                                    items: ["System", "Institutions", "Users", "Examinations", "Payments"],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => category = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _buildDialogDropdown(
                                    label: 'Priority Level',
                                    value: priority,
                                    icon: Icons.flag_outlined,
                                    items: ["Critical", "High", "Warning", "Info"],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => priority = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildDialogDropdown(
                              label: 'Status',
                              value: status,
                              icon: Icons.timelapse_rounded,
                              items: ["New", "In Progress", "Resolved"],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => status = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),

                    // ── Footer ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: _isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textSecondary,
                              side: BorderSide(color: _borderColor),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.save_rounded, size: 16),
                            label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              try {
                                final bool newIsRead = (status == "Resolved")
                                    ? true
                                    : (status == "New" ? false : (alert['is_read'] ?? false));
                                final res = await ApiService().put('/admin/system-alerts/${alert['id']}', {
                                  "title": titleController.text.trim(),
                                  "description": descController.text.trim(),
                                  "category": category,
                                  "priority": priority,
                                  "status": status,
                                  "is_read": newIsRead,
                                });
                                if (res['success'] == true) {
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  _fetchAlertsData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Alert updated successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint("Error updating alert: $e");
                              }
                            },
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
      },
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    // CRITICAL: Defensive guard to ensure value exists in items
    final safeItems = List<String>.from(items);
    if (!safeItems.contains(value)) {
      if (value.isNotEmpty) {
        safeItems.insert(0, value);
      } else if (safeItems.isNotEmpty) {
        value = safeItems.first;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    value: value,
                    isExpanded: true,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _textPrimary,
                    ),
                    dropdownColor: _cardBg,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: _textSecondary),
                    onChanged: onChanged,
                    items: safeItems.map((item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
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

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background track ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    canvas.drawCircle(center, radius, bgPaint);

    final double total = critical + high + warning + info;
    if (total == 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;

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
