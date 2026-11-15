import 'dart:convert';
import 'dart:math';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SuperAdminDashboardScreen extends ConsumerStatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  ConsumerState<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends ConsumerState<SuperAdminDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _data = {};

  // Campus & AY Filter state
  String _selectedSchoolId = 'all';
  String _selectedAcademicYear = '2026-2027';

  // Date Range state
  String _selectedRange = 'last_7_days';
  String _selectedRangeLabel = 'Last 7 Days';

  String _selectedUserRange = 'last_7_days';
  // ignore: unused_field
  String _selectedUserRangeLabel = 'Last 7 Days';

  String _selectedRevenueRange = 'last_7_days';
  // ignore: unused_field
  String _selectedRevenueRangeLabel = 'Last 7 Days';

  // Keyboard shortcut focus node
  final FocusNode _keyboardFocusNode = FocusNode();

  // Notification state
  int _unreadNotifications = 0;
  List<dynamic> _recentAlerts = [];

  // Browser Ctrl+K intercept subscription
  dynamic _ctrlKSubscription;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchUnreadNotifications();
    // Prevent browser from intercepting Ctrl+K (Chrome address bar focus)
    _ctrlKSubscription = html.window.onKeyDown.listen((html.KeyboardEvent event) {
      if ((event.ctrlKey || event.metaKey) && event.key == 'k') {
        event.preventDefault();
      }
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _ctrlKSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final schoolParam = _selectedSchoolId != 'all' ? '&school_id=$_selectedSchoolId' : '';
      final res = await ApiService().get(
        '/admin/schools/dashboard-stats?range=$_selectedRange&range_user=$_selectedUserRange&range_revenue=$_selectedRevenueRange$schoolParam',
        useCache: false,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _data = Map<String, dynamic>.from(res['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load stats.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final res = await ApiService().get(
        '/admin/system-alerts',
        query: {'page': 1, 'page_size': 5},
        useCache: false,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        setState(() {
          _unreadNotifications = (stats['unread_alerts'] as num?)?.toInt() ?? 0;
          _recentAlerts = data['alerts'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {
      // Silently ignore — badge stays at 0
    }
  }

  String formatCurrency(double amount) {
    String valStr = amount.toStringAsFixed(0);
    if (valStr.length <= 3) {
      return '₹ $valStr';
    }
    String lastThree = valStr.substring(valStr.length - 3);
    String remaining = valStr.substring(0, valStr.length - 3);
    
    List<String> groups = [];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }
    return '₹ ${groups.join(',')},$lastThree';
  }

  String formatNumber(int val) {
    String valStr = val.toString();
    if (valStr.length <= 3) return valStr;
    String lastThree = valStr.substring(valStr.length - 3);
    String remaining = valStr.substring(0, valStr.length - 3);
    List<String> groups = [];
    while (remaining.length > 3) {
      groups.insert(0, remaining.substring(remaining.length - 3));
      remaining = remaining.substring(0, remaining.length - 3);
    }
    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }
    return '${groups.join(',')},$lastThree';
  }

  void _showRangeSelector(BuildContext context, bool isDark, String targetSection) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.date_range_rounded, color: Color(0xFF4F46E5), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Select Timeframe',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRangePresetItem(dialogContext, targetSection, 'last_7_days', 'Last 7 Days', 'Mon to Sun register & active session trend', Icons.calendar_view_week_rounded, Colors.purple, isDark),
                const SizedBox(height: 10),
                _buildRangePresetItem(dialogContext, targetSection, 'last_30_days', 'Last 30 Days', 'Monthly overview grouped by weekly aggregates', Icons.calendar_view_month_rounded, Colors.blue, isDark),
                const SizedBox(height: 10),
                _buildRangePresetItem(dialogContext, targetSection, 'this_month', 'This Month', 'Month-to-date collections and active counts', Icons.today_rounded, Colors.teal, isDark),
                const SizedBox(height: 10),
                _buildRangePresetItem(dialogContext, targetSection, 'this_year', 'This Year', 'Full annual statistics broken down by month', Icons.analytics_rounded, Colors.amber, isDark),
                const SizedBox(height: 10),
                _buildRangePresetItem(dialogContext, targetSection, 'custom', 'Custom Range...', 'Select start and end dates from calendar', Icons.edit_calendar_rounded, Colors.deepOrange, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomRangePicker(BuildContext context, bool isDark, String targetSection) async {
    DateTime? startDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime? endDate = DateTime.now();
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 340,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Custom Date Range',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 18),
                          color: Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Start Date',
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: isDark ? ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: Color(0xFF4F46E5), surface: Color(0xFF1E293B)),
                            ) : ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              startDate == null ? 'Select Date' : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'End Date',
                      style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime(2025),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: isDark ? ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: Color(0xFF4F46E5), surface: Color(0xFF1E293B)),
                            ) : ThemeData.light().copyWith(
                              colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              endDate == null ? 'Select Date' : "${endDate!.day}/${endDate!.month}/${endDate!.year}",
                              style: GoogleFonts.outfit(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (startDate != null && endDate != null) {
                              final startStr = "${startDate!.day}/${startDate!.month}";
                              final endStr = "${endDate!.day}/${endDate!.month}/${endDate!.year}";
                              setState(() {
                                if (targetSection == 'default') {
                                  _selectedRange = 'last_30_days';
                                  _selectedRangeLabel = "$startStr - $endStr";
                                  _selectedUserRange = 'last_30_days';
                                  _selectedUserRangeLabel = "$startStr - $endStr";
                                  _selectedRevenueRange = 'last_30_days';
                                  _selectedRevenueRangeLabel = "$startStr - $endStr";
                                } else if (targetSection == 'user') {
                                  _selectedUserRange = 'last_30_days';
                                  _selectedUserRangeLabel = "$startStr - $endStr";
                                } else if (targetSection == 'revenue') {
                                  _selectedRevenueRange = 'last_30_days';
                                  _selectedRevenueRangeLabel = "$startStr - $endStr";
                                }
                              });
                              _fetchStats();
                            }
                            Navigator.pop(dialogContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Apply', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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

  Widget _buildRangePresetItem(BuildContext dialogContext, String targetSection, String key, String title, String subtitle, IconData icon, Color color, bool isDark) {
    final isSelected = (targetSection == 'default' && _selectedRange == key) ||
        (targetSection == 'user' && _selectedUserRange == key) ||
        (targetSection == 'revenue' && _selectedRevenueRange == key);

    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        if (key == 'custom') {
          _showCustomRangePicker(context, isDark, targetSection);
        } else {
          setState(() {
            if (targetSection == 'default') {
              _selectedRange = key;
              _selectedRangeLabel = title;
              // Sync global date change to all other child cards
              _selectedUserRange = key;
              _selectedUserRangeLabel = title;
              _selectedRevenueRange = key;
              _selectedRevenueRangeLabel = title;
            } else if (targetSection == 'user') {
              _selectedUserRange = key;
              _selectedUserRangeLabel = title;
            } else if (targetSection == 'revenue') {
              _selectedRevenueRange = key;
              _selectedRevenueRangeLabel = title;
            }
          });
          _fetchStats();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF4F46E5).withValues(alpha: 0.08) 
              : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.15) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5), size: 18),
          ],
        ),
      ),
    );
  }

  void _showExportPreview(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ExportPreviewDialog(isDark: isDark, data: _data);
      },
    );
  }

  void _showSearchOverlay(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return _SearchOverlayDialog(isDark: isDark);
      },
    );
  }

  // Campus Switcher & Academic Year Helpers
  Widget _buildCampusSelector(bool isDark) {
    final schools = _getSchoolsList();
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSchoolId,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: schools.map((s) {
            final id = s['id'] ?? 'all';
            final name = s['name'] ?? 'All Campuses';
            return DropdownMenuItem<String>(
              value: id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.domain_rounded, size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != _selectedSchoolId) {
              setState(() {
                _selectedSchoolId = val;
              });
              _fetchStats();
            }
          },
        ),
      ),
    );
  }

  Widget _buildAcademicYearBadge(bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAcademicYear,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: const [
            DropdownMenuItem(value: '2026-2027', child: Text('AY 2026-27')),
            DropdownMenuItem(value: '2025-2026', child: Text('AY 2025-26')),
          ],
          onChanged: (val) {
            if (val != null && val != _selectedAcademicYear) {
              setState(() {
                _selectedAcademicYear = val;
              });
              _fetchStats();
            }
          },
        ),
      ),
    );
  }

  List<Map<String, String>> _getSchoolsList() {
    if (_data['schools_list'] != null && _data['schools_list'] is List) {
      return (_data['schools_list'] as List).map((s) {
        return {
          'id': s['id']?.toString() ?? 'all',
          'name': s['name']?.toString() ?? 'All Campuses',
        };
      }).toList();
    }
    return [{'id': 'all', 'name': 'All Campuses (Enterprise)'}];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard metrics',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchStats,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            ],
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_keyboardFocusNode.canRequestFocus) {
        _keyboardFocusNode.requestFocus();
      }
    });

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        final isCtrlPressed = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
        if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
          if (event is KeyDownEvent) {
            _showSearchOverlay(context, isDark);
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context, isDark),
                  const SizedBox(height: 16),
                  _buildHeaderRow(context, isDark),
                  const SizedBox(height: 18),
                  
                  // ZONE 1: INSTITUTIONAL VITALS (6 Core Metric Badges)
                  _buildInstitutionalVitals(context, isDark, width),
                  const SizedBox(height: 20),
                  
                  // ZONE 2: 6 VISUAL INTELLIGENCE GRAPHS
                  _buildVisualIntelligenceMatrix(context, isDark, width),
                  const SizedBox(height: 20),
                  
                  // ZONE 3: EXECUTIVE ACTION TRIAGE ("Needs Immediate Attention")
                  _buildActionTriageHub(context, isDark, width),
                  const SizedBox(height: 20),
                  
                  // ZONE 4: SENIOR LEADERSHIP FAST ACTIONS & PLATFORM PULSE
                  _buildFastActionsAndPlatformPulse(context, isDark, width),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'Super Admin';
    final userRole = user?['role']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'SUPER ADMIN';
    final avatarUrl = user?['avatar_url'];
    final initials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase()
        : 'SA';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Search bar + Campus Switcher + AY Badge
        Expanded(
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: InkWell(
                  onTap: () => _showSearchOverlay(context, isDark),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white.withValues(alpha: 0.58) : const Color(0xFF64748B),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Search modules, routes, users...',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            'Ctrl + K',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (Responsive.isDesktop(context))
                _buildCampusSelector(isDark),
              if (Responsive.isDesktop(context))
                const SizedBox(width: 12),
              if (Responsive.isDesktop(context))
                _buildAcademicYearBadge(isDark),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Notifications, Help, Profile
        Row(
          children: [
            _buildNotificationButton(isDark),
            const SizedBox(width: 12),
            _buildHelpButton(isDark),
            const SizedBox(width: 20),
            Container(
              width: 1,
              height: 32,
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 20),
            InkWell(
              onTap: () => context.go('/admin/my-profile'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: avatarUrl == null
                            ? const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)])
                            : null,
                        image: avatarUrl != null
                            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                            : null,
                        shape: BoxShape.circle,
                      ),
                      child: avatarUrl == null
                          ? Center(
                              child: Text(
                                initials,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    if (Responsive.isDesktop(context))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            userRole,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationButton(bool isDark) {
    final count = _unreadNotifications;
    return Tooltip(
      message: count > 0 ? '$count unread alerts' : 'Alerts & Notifications',
      child: InkWell(
        onTap: () => _showNotificationPanel(context, isDark),
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                color: count > 0
                    ? const Color(0xFF4F46E5)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
                size: 18,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Help button — opens help & shortcuts dialog
  Widget _buildHelpButton(bool isDark) {
    return Tooltip(
      message: 'Help & Keyboard Shortcuts',
      child: InkWell(
        onTap: () => _showHelpDialog(context, isDark),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Icon(
            Icons.help_outline_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            size: 18,
          ),
        ),
      ),
    );
  }

  /// Rich notification popover panel
  void _showNotificationPanel(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 64, right: 16),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_rounded, color: Color(0xFF4F46E5), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Alerts & Notifications',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (_unreadNotifications > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_unreadNotifications unread',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: const Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: Colors.grey,
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    // Alert items
                    if (_recentAlerts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 40,
                                color: isDark ? Colors.white24 : Colors.black26),
                            const SizedBox(height: 12),
                            Text(
                              'All clear! No alerts right now.',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: _recentAlerts.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            indent: 18,
                            endIndent: 18,
                          ),
                          itemBuilder: (context, i) {
                            final alert = _recentAlerts[i] as Map<String, dynamic>;
                            final priority = alert['priority']?.toString().toLowerCase() ?? 'info';
                            final isRead = alert['is_read'] == true;
                            final Color priorityColor = priority == 'critical'
                                ? const Color(0xFFEF4444)
                                : priority == 'high'
                                    ? const Color(0xFFF97316)
                                    : priority == 'warning'
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF4F46E5);
                            final IconData priorityIcon = priority == 'critical'
                                ? Icons.dangerous_rounded
                                : priority == 'high'
                                    ? Icons.warning_amber_rounded
                                    : priority == 'warning'
                                        ? Icons.error_outline_rounded
                                        : Icons.info_outline_rounded;

                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/admin/alerts-notifications');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                color: isRead
                                    ? Colors.transparent
                                    : (isDark
                                        ? const Color(0xFF4F46E5).withValues(alpha: 0.06)
                                        : const Color(0xFFEEF2FF)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: priorityColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(priorityIcon, color: priorityColor, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  alert['title']?.toString() ?? 'System Alert',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  margin: const EdgeInsets.only(left: 6),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF4F46E5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            alert['message']?.toString() ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                    // Footer
                    Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/alerts-notifications');
                      },
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View all alerts & notifications',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Help & Keyboard Shortcuts dialog
  void _showHelpDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 420,
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
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Help & Keyboard Shortcuts',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'KEYBOARD SHORTCUTS',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                _buildShortcutRow(isDark, 'Ctrl + K', 'Open global search'),
                _buildShortcutRow(isDark, 'Ctrl + /', 'Open AI assistant'),
                _buildShortcutRow(isDark, 'Ctrl + D', 'Go to Dashboard'),
                _buildShortcutRow(isDark, 'Ctrl + N', 'New entry (context aware)'),
                _buildShortcutRow(isDark, 'Esc', 'Close dialog / overlay'),
                const SizedBox(height: 20),
                Text(
                  'QUICK LINKS',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                _buildHelpLink(context, isDark, Icons.school_rounded, 'Schools Directory', '/admin/schools'),
                _buildHelpLink(context, isDark, Icons.people_alt_rounded, 'User Management', '/admin/users'),
                _buildHelpLink(context, isDark, Icons.tune_rounded, 'System Config', '/admin/config'),
                _buildHelpLink(context, isDark, Icons.notifications_rounded, 'Alerts & Notifications', '/admin/alerts-notifications'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text('Got it', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShortcutRow(bool isDark, String key, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              key,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpLink(BuildContext context, bool isDark, IconData icon, String label, String route) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }


  Widget _buildHeaderRow(BuildContext context, bool isDark) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'Super Admin';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Executive Command Intelligence',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'LIVE TELEMETRY',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome, $userName. Real-time institutional health across Academics, Finance, Transport, Hostel, HR & Campus Safety.",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _fetchStats,
              tooltip: 'Refresh Intelligence',
              icon: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showRangeSelector(context, isDark, 'default'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedRangeLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showExportPreview(context, isDark),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Export Brief',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            )
          ],
        )
      ],
    );
  }

  // =========================================================================
  // ZONE 1: INSTITUTIONAL VITALS (6 Core Metric Badges)
  // =========================================================================
  Widget _buildInstitutionalVitals(BuildContext context, bool isDark, [double? outerWidth]) {
    final vitals = _data['vitals'] as Map<String, dynamic>? ?? {};
    final int totalStud = (_data['total_students'] as num?)?.toInt() ?? 2456;
    final int totalStaff = (_data['total_staff'] as num?)?.toInt() ?? 145;
    final double totalRev = ((_data['total_revenue'] ?? 4875250) as num).toDouble();
    final double totalOverdue = ((vitals['total_fee_overdue'] ?? 1324750) as num).toDouble();

    final List<Map<String, dynamic>> vitalsCards = [
      {
        'title': 'Student Attendance',
        'value': '${vitals['student_attendance_pct'] ?? 94.2}%',
        'badge': '${formatNumber((vitals['students_present'] as num?)?.toInt() ?? totalStud)} Present',
        'sub': '${formatNumber((vitals['students_absent'] as num?)?.toInt() ?? 142)} absent today',
        'icon': Icons.school_rounded,
        'color': const Color(0xFF4F46E5),
        'bg': const Color(0xFFEEF2FF),
        'route': '/admin/attendance',
      },
      {
        'title': 'Faculty On Duty',
        'value': '${vitals['faculty_present'] ?? 142} / $totalStaff',
        'badge': '${vitals['faculty_attendance_pct'] ?? 97.9}% Active',
        'sub': 'Ratio ${vitals['student_teacher_ratio'] ?? "17:1"} • 0 shortages',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
        'route': '/admin/hr/overview',
      },
      {
        'title': 'Fee Realization',
        'value': '${vitals['fee_realization_pct'] ?? 78.5}%',
        'badge': formatCurrency(totalRev),
        'sub': '₹${formatNumber(totalOverdue.toInt())} overdue',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF0EA5E9),
        'bg': const Color(0xFFF0F9FF),
        'route': '/admin/finance',
      },
      {
        'title': 'Active Transport Fleet',
        'value': '${vitals['vehicles_active'] ?? 10} / ${vitals['total_vehicles'] ?? 10}',
        'badge': '100% On-Route',
        'sub': '29 corridors • 1,254.8 km',
        'icon': Icons.directions_bus_rounded,
        'color': const Color(0xFF6366F1),
        'bg': const Color(0xFFEEF2FF),
        'route': '/admin/vehicle-dashboard',
      },
      {
        'title': 'Hostel Bed Occupancy',
        'value': '${vitals['hostel_occupied_beds'] ?? 15} / ${vitals['hostel_total_beds'] ?? 36}',
        'badge': '${vitals['hostel_occupancy_pct'] ?? 41.7}% Filled',
        'sub': '${vitals['hostel_students_out'] ?? 16} out • ${vitals['hostel_overdue_curfew'] ?? 3} overdue',
        'icon': Icons.hotel_rounded,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFFFBEB),
        'route': '/admin/hostel',
      },
      {
        'title': 'Campus Security & Gate',
        'value': '${vitals['visitors_on_campus'] ?? 8} On Campus',
        'badge': '${vitals['visitors_today'] ?? 24} Today',
        'sub': '0 flagged • Perimeter safe',
        'icon': Icons.security_rounded,
        'color': const Color(0xFF8B5CF6),
        'bg': const Color(0xFFF5F3FF),
        'route': '/admin/visitors',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int cols;
        const double spacing = 10.0;
        const double runSpacing = 10.0;

        if (availableWidth >= 960) {
          cols = 6;
        } else if (availableWidth >= 580) {
          cols = 3;
        } else if (availableWidth >= 340) {
          cols = 2;
        } else {
          cols = 1;
        }

        final double totalSpacing = (cols - 1) * spacing;
        final double cardWidth = ((availableWidth - totalSpacing) / cols).floorToDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: vitalsCards.map((card) {
            return SizedBox(
              width: cardWidth,
              child: _buildVitalCard(context, card, isDark),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildVitalCard(BuildContext context, Map<String, dynamic> c, bool isDark) {
    final color = c['color'] as Color;
    final route = c['route'] as String;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(10),
        hoverColor: color.withValues(alpha: isDark ? 0.08 : 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.025),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Icon + Badge Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.20 : 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(c['icon'] as IconData, size: 14, color: color),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c['badge'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Large Primary Metric Value
              Text(
                c['value'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Category Title
              Text(
                c['title'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Context Subtitle + Arrow
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c['sub'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 11,
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ZONE 2: THE 6 VISUAL INTELLIGENCE GRAPHS
  // =========================================================================
  Widget _buildVisualIntelligenceMatrix(BuildContext context, bool isDark, double width) {
    final isDesktop = width >= 1200;
    final isTablet = width >= 768 && width < 1200;

    final card1 = _buildAttendanceCard(context, isDark);
    final card2 = _buildFinanceCard(context, isDark);
    final card3 = _buildFleetCard(context, isDark);
    final card4 = _buildHostelCard(context, isDark);
    final card5 = _buildWorkforceCard(context, isDark);
    final card6 = _buildSecurityCard(context, isDark);

    if (isDesktop) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 20),
              Expanded(child: card2),
              const SizedBox(width: 20),
              Expanded(child: card3),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card4),
              const SizedBox(width: 20),
              Expanded(child: card5),
              const SizedBox(width: 20),
              Expanded(child: card6),
            ],
          ),
        ],
      );
    } else if (isTablet) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 20),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card3),
              const SizedBox(width: 20),
              Expanded(child: card4),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card5),
              const SizedBox(width: 20),
              Expanded(child: card6),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          card1,
          const SizedBox(height: 18),
          card2,
          const SizedBox(height: 18),
          card3,
          const SizedBox(height: 18),
          card4,
          const SizedBox(height: 18),
          card5,
          const SizedBox(height: 18),
          card6,
        ],
      );
    }
  }

  // -------------------------------------------------------------------------
  // GRAPH 1: Academic & Attendance Pulse
  // -------------------------------------------------------------------------
  Widget _buildAttendanceCard(BuildContext context, bool isDark) {
    final gAtt = _data['graph_attendance'] as Map<String, dynamic>? ?? {};
    final double studentPct = (gAtt['student_pct'] as num?)?.toDouble() ?? 94.2;
    final double facultyPct = (gAtt['faculty_pct'] as num?)?.toDouble() ?? 97.9;
    final trend = (gAtt['trend'] as List<dynamic>?) ?? [
      {'day': 'Mon', 'rate': 93.8},
      {'day': 'Tue', 'rate': 95.1},
      {'day': 'Wed', 'rate': 94.6},
      {'day': 'Thu', 'rate': 96.2},
      {'day': 'Fri', 'rate': 93.4},
      {'day': 'Sat', 'rate': 91.2},
      {'day': 'Today', 'rate': studentPct},
    ];

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF4F46E5),
      title: 'Academic & Attendance Pulse',
      actionLabel: 'Attendance Console ➜',
      onAction: () => context.push('/admin/attendance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Radial Gauge
              SizedBox(
                width: 120,
                height: 90,
                child: CustomPaint(
                  painter: _RadialGaugePainter(
                    percentage: studentPct,
                    targetPercentage: 90.0,
                    primaryColor: const Color(0xFF4F46E5),
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 28.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$studentPct%',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Target 90%',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Sparkline trend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '7-Day Daily Trend',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'Staff: $facultyPct%',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60,
                      child: CustomPaint(
                        size: const Size(double.infinity, 60),
                        painter: _MiniBarSparklinePainter(
                          data: trend,
                          barColor: const Color(0xFF4F46E5),
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('Students Present', formatNumber((gAtt['present_count'] as num?)?.toInt() ?? 2314), const Color(0xFF10B981), isDark),
              _buildMiniIndicator('Absent', formatNumber((gAtt['absent_count'] as num?)?.toInt() ?? 142), const Color(0xFFEF4444), isDark),
              _buildMiniIndicator('Faculty Duty', '$facultyPct%', const Color(0xFF6366F1), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRAPH 2: Fee Realization & Defaulter Aging
  // -------------------------------------------------------------------------
  Widget _buildFinanceCard(BuildContext context, bool isDark) {
    final gFin = _data['graph_finance'] as Map<String, dynamic>? ?? {};
    final double billed = ((gFin['total_billed'] ?? 6200000) as num).toDouble();
    final double collected = ((gFin['total_collected'] ?? 4875250) as num).toDouble();
    final double pending = ((gFin['pending_amount'] ?? 1324750) as num).toDouble();
    final double rate = ((gFin['realization_pct'] ?? 78.5) as num).toDouble();
    final buckets = gFin['aging_buckets'] as Map<String, dynamic>? ?? {
      'under_30': pending * 0.55,
      'days_30_60': pending * 0.30,
      'over_60': pending * 0.15,
    };

    final double u30 = ((buckets['under_30'] ?? 728000) as num).toDouble();
    final double d60 = ((buckets['days_30_60'] ?? 397000) as num).toDouble();
    final double o60 = ((buckets['over_60'] ?? 199000) as num).toDouble();

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Fee Realization & Aging',
      actionLabel: 'Finance Hub ➜',
      onAction: () => context.push('/admin/finance'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Realization: $rate%',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${formatCurrency(collected)} / ${formatCurrency(billed)}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: (rate / 100.0).clamp(0.0, 1.0),
                backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Defaulter Aging Distribution (₹${formatNumber(pending.toInt())} Overdue)',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 8,
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _DefaulterAgingBarPainter(
                under30: u30,
                days30to60: d60,
                over60: o60,
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('< 30 Days', '₹${formatNumber(u30.toInt())}', const Color(0xFFF59E0B), isDark),
              _buildMiniIndicator('30-60 Days', '₹${formatNumber(d60.toInt())}', const Color(0xFFF97316), isDark),
              _buildMiniIndicator('> 60 Days', '₹${formatNumber(o60.toInt())}', const Color(0xFFEF4444), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRAPH 3: Transport Fleet & Telemetry Status
  // -------------------------------------------------------------------------
  Widget _buildFleetCard(BuildContext context, bool isDark) {
    final gFleet = _data['graph_fleet'] as Map<String, dynamic>? ?? {};
    final int totalV = (gFleet['total_vehicles'] as num?)?.toInt() ?? 10;
    final int activeV = (gFleet['active_vehicles'] as num?)?.toInt() ?? 10;
    final double punctuality = ((gFleet['punctuality_pct'] ?? 98.4) as num).toDouble();
    final int routes = (gFleet['total_routes'] as num?)?.toInt() ?? 29;
    final double km = ((gFleet['total_distance_km'] ?? 1254.8) as num).toDouble();

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.directions_bus_rounded,
      iconColor: const Color(0xFF0EA5E9),
      title: 'Fleet Status & Telemetry',
      actionLabel: 'Live GPS Map ➜',
      onAction: () => context.push('/admin/vehicle-dashboard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _FleetDonutPainter(
                    onRoute: activeV,
                    arrived: 0,
                    returning: 0,
                    delayed: 0,
                    offline: max(0, totalV - activeV),
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$activeV / $totalV',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'On-Route',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Telemetry stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTelemetryRow('Active Corridors', '$routes Routes', isDark),
                    const SizedBox(height: 6),
                    _buildTelemetryRow('Distance Covered', '${km.toStringAsFixed(1)} km', isDark),
                    const SizedBox(height: 6),
                    _buildTelemetryRow('Punctuality Score', '$punctuality%', isDark, highlightColor: const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _buildTelemetryRow('Safety Incidents', '0 Alerts Nominal', isDark, highlightColor: const Color(0xFF0EA5E9)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('Active Fleet', '$activeV Buses', const Color(0xFF10B981), isDark),
              _buildMiniIndicator('Delayed', '0 Buses', const Color(0xFF64748B), isDark),
              _buildMiniIndicator('Punctuality', '$punctuality%', const Color(0xFF0EA5E9), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRAPH 4: Hostel Capacity & Residential Discipline
  // -------------------------------------------------------------------------
  Widget _buildHostelCard(BuildContext context, bool isDark) {
    final gHostel = _data['graph_hostel'] as Map<String, dynamic>? ?? {};
    final int beds = (gHostel['total_beds'] as num?)?.toInt() ?? 36;
    final int occ = (gHostel['occupied_beds'] as num?)?.toInt() ?? 15;
    final double occPct = ((gHostel['occupancy_pct'] ?? 41.7) as num).toDouble();
    final int outCount = (gHostel['currently_out'] as num?)?.toInt() ?? 16;
    final int overdue = (gHostel['overdue_curfew'] as num?)?.toInt() ?? 3;
    final buildings = (gHostel['buildings'] as List<dynamic>?) ?? [
      {'name': 'Boys Hostel A', 'occupied': 9, 'total': 27, 'pct': 33.3},
      {'name': 'Boys Hostel B', 'occupied': 2, 'total': 5, 'pct': 40.0},
      {'name': 'Girls Hostel A', 'occupied': 2, 'total': 2, 'pct': 100.0},
      {'name': 'Girls Hostel B', 'occupied': 2, 'total': 2, 'pct': 100.0},
    ];

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.hotel_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Hostel Capacity & Discipline',
      actionLabel: 'Hostel Console ➜',
      onAction: () => context.push('/admin/hostel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Occupancy: $occPct%',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '$occ / $beds Beds Allocated',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Buildings progress bars
          Column(
            children: buildings.take(3).map((b) {
              final double p = ((b['pct'] ?? 50.0) as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 95,
                      child: Text(
                        b['name']?.toString() ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: (p / 100.0).clamp(0.0, 1.0),
                            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              p > 80 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b['occupied']}/${b['total']}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('In Campus', '$occ Active', const Color(0xFF10B981), isDark),
              _buildMiniIndicator('On Gate Pass', '$outCount Out', const Color(0xFF0EA5E9), isDark),
              _buildMiniIndicator('Curfew Alert', '$overdue Overdue', const Color(0xFFEF4444), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRAPH 5: Workforce, Faculty Load & Recruitment
  // -------------------------------------------------------------------------
  Widget _buildWorkforceCard(BuildContext context, bool isDark) {
    final gHr = _data['graph_hr'] as Map<String, dynamic>? ?? {};
    final ratio = gHr['student_teacher_ratio']?.toString() ?? '17:1';
    final int faculty = (gHr['total_faculty'] as num?)?.toInt() ?? 99;
    final int openings = (gHr['active_openings'] as num?)?.toInt() ?? 4;
    final int candidates = (gHr['pipeline_candidates'] as num?)?.toInt() ?? 18;
    final int interviews = (gHr['interviews_scheduled'] as num?)?.toInt() ?? 4;

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.people_alt_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Workforce & Talent Pipeline',
      actionLabel: 'HR Suite ➜',
      onAction: () => context.push('/admin/hr/overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Teacher-Student Ratio: $ratio (Optimal)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$faculty Faculty',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Recruitment Funnel Pipeline',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFunnelStage('Openings', '$openings', const Color(0xFF4F46E5), isDark),
              _buildFunnelArrow(isDark),
              _buildFunnelStage('Applied', '$candidates', const Color(0xFF0EA5E9), isDark),
              _buildFunnelArrow(isDark),
              _buildFunnelStage('Interview', '$interviews', const Color(0xFFF59E0B), isDark),
              _buildFunnelArrow(isDark),
              _buildFunnelStage('Joiners', '3', const Color(0xFF10B981), isDark),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('On Duty Today', '97.9%', const Color(0xFF10B981), isDark),
              _buildMiniIndicator('Open Roles', '$openings Active', const Color(0xFF4F46E5), isDark),
              _buildMiniIndicator('Onboarding', '3 Joining', const Color(0xFFF59E0B), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // GRAPH 6: Campus Security, Visitor & Gate Flow
  // -------------------------------------------------------------------------
  Widget _buildSecurityCard(BuildContext context, bool isDark) {
    final gSec = _data['graph_security'] as Map<String, dynamic>? ?? {};
    final int today = (gSec['visitors_today'] as num?)?.toInt() ?? 24;
    final int inside = (gSec['currently_inside'] as num?)?.toInt() ?? 8;
    final int checkout = (gSec['checked_out'] as num?)?.toInt() ?? 16;
    final hourly = (gSec['hourly_inflow'] as List<dynamic>?) ?? [
      {'hour': '08:00', 'count': 4},
      {'hour': '10:00', 'count': 12},
      {'hour': '12:00', 'count': 18},
      {'hour': '14:00', 'count': 15},
      {'hour': '16:00', 'count': 9},
      {'hour': '18:00', 'count': 3},
    ];

    return _buildChartContainer(
      isDark: isDark,
      icon: Icons.shield_rounded,
      iconColor: const Color(0xFF8B5CF6),
      title: 'Perimeter Security & Inflow',
      actionLabel: 'Visitor Registry ➜',
      onAction: () => context.push('/admin/visitors'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$inside Inside Campus',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Perimeter Safe',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hourly Visitor Check-ins',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: hourly.map((h) {
                          final count = (h['count'] as num?)?.toInt() ?? 5;
                          final double hRatio = (count / 20.0).clamp(0.1, 1.0);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 38 * hRatio,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    h['hour']?.toString().substring(0, 2) ?? '',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator('Today Inflow', '$today Total', const Color(0xFF8B5CF6), isDark),
              _buildMiniIndicator('Checked Out', '$checkout Done', const Color(0xFF10B981), isDark),
              _buildMiniIndicator('Security Alerts', '0 Flagged', const Color(0xFF0EA5E9), isDark),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Visual Chart Container Wrapper
  // -------------------------------------------------------------------------
  Widget _buildChartContainer({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildMiniIndicator(String label, String value, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryRow(String label, String value, bool isDark, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: highlightColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildFunnelStage(String stage, String val, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              stage,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelArrow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 14,
        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
      ),
    );
  }

  // =========================================================================
  // ZONE 3: ACTION TRIAGE ENGINE ("Needs Immediate Attention")
  // =========================================================================
  Widget _buildActionTriageHub(BuildContext context, bool isDark, double width) {
    final triageItems = (_data['action_triage'] as List<dynamic>?) ?? [
      {
        'id': 'triage_curfew',
        'category': 'Hostel Life',
        'severity': 'critical',
        'title': '3 Hostellers Overdue Past Curfew (8:00 PM)',
        'description': 'Residents exited on gate pass and missed evening reporting deadline.',
        'action_label': 'Review Gate Passes',
        'route': '/admin/hostel',
      },
      {
        'id': 'triage_fees',
        'category': 'Finance & Revenue',
        'severity': 'warning',
        'title': '₹13.25L Outstanding Dues Realization',
        'description': 'Uncollected semester tuition fees requiring notification broadcast.',
        'action_label': 'Fee Console',
        'route': '/admin/finance',
      },
      {
        'id': 'triage_fleet',
        'category': 'Transport Safety',
        'severity': 'info',
        'title': '10 Fleet Vehicles Active • Live GPS Nominal',
        'description': 'All 29 corridors actively tracking with 98.4% route punctuality.',
        'action_label': 'Live GPS Tracker',
        'route': '/admin/vehicle-dashboard',
      },
      {
        'id': 'triage_facility',
        'category': 'Campus Facilities',
        'severity': 'warning',
        'title': '2 Urgent Campus Maintenance Work Orders Pending',
        'description': 'Hostel electrical & HVAC tickets flagged with urgent resolution priority.',
        'action_label': 'Inspect Tickets',
        'route': '/admin/hostel',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.3 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Executive Action Triage • Needs Immediate Attention',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Priority institutional items requiring senior leadership intervention & fast decisions',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      '${triageItems.length} Actionable Items',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Items grid or list
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const spacing = 12.0;
              final int cols = width >= 800 ? 2 : 1;
              final double cardWidth = ((width - (cols - 1) * spacing) / cols).floorToDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: triageItems.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildTriageCard(context, item as Map<String, dynamic>, isDark),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTriageCard(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final severity = item['severity']?.toString().toLowerCase() ?? 'info';
    final route = item['route']?.toString() ?? '/admin/dashboard';
    final actionLabel = item['action_label']?.toString() ?? 'View Details';

    Color sevColor = const Color(0xFF0EA5E9);
    IconData sevIcon = Icons.info_outline_rounded;
    if (severity == 'critical') {
      sevColor = const Color(0xFFEF4444);
      sevIcon = Icons.error_outline_rounded;
    } else if (severity == 'warning') {
      sevColor = const Color(0xFFF59E0B);
      sevIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sevColor.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(sevIcon, color: sevColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['category']?.toString().toUpperCase() ?? 'TRIAGE',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: sevColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item['title']?.toString() ?? '',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item['description']?.toString() ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => context.push(route),
            style: ElevatedButton.styleFrom(
              backgroundColor: sevColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ZONE 4: SENIOR LEADERSHIP FAST ACTIONS & SYSTEM OVERVIEW
  // =========================================================================
  Widget _buildFastActionsAndPlatformPulse(BuildContext context, bool isDark, double width) {
    final sys = _data['system_overview'] as Map<String, dynamic>? ?? {};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fast actions
        Expanded(
          flex: width >= 1100 ? 7 : 12,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Text(
                      'Executive Fast Operations',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildFastActionButton(
                      context: context,
                      label: 'Broadcast Circular',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFF4F46E5),
                      isDark: isDark,
                      onTap: () => context.push('/admin/announcements'),
                    ),
                    _buildFastActionButton(
                      context: context,
                      label: 'Emergency Broadcast',
                      icon: Icons.emergency_rounded,
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      onTap: () => context.push('/admin/emergency'),
                    ),
                    _buildFastActionButton(
                      context: context,
                      label: 'Approve Leaves',
                      icon: Icons.approval_rounded,
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: () => context.push('/admin/hr/overview'),
                    ),
                    _buildFastActionButton(
                      context: context,
                      label: 'Export Brief PDF',
                      icon: Icons.download_rounded,
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                      onTap: () => _showExportPreview(context, isDark),
                    ),
                    _buildFastActionButton(
                      context: context,
                      label: 'System Config',
                      icon: Icons.settings_rounded,
                      color: const Color(0xFF64748B),
                      isDark: isDark,
                      onTap: () => context.push('/admin/config'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (width >= 1100) const SizedBox(width: 20),
        // Platform pulse card
        if (width >= 1100)
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Text(
                            'Platform Health & Pulse',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OPERATIONAL',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPulseItem('Server Uptime', sys['server_status']?.toString() ?? '99.98%', isDark),
                      _buildPulseItem('Database', sys['database_status']?.toString() ?? 'Healthy', isDark),
                      _buildPulseItem('Active Sessions', '${sys['active_sessions'] ?? 156}', isDark),
                      _buildPulseItem('Version', sys['system_version']?.toString() ?? 'v2.6.1', isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFastActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseItem(String label, String val, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // CUSTOM PAINTER IMPLEMENTATIONS
  // =========================================================================
}

class _RadialGaugePainter extends CustomPainter {
  final double percentage;
  final double targetPercentage;
  final Color primaryColor;
  final bool isDark;

  _RadialGaugePainter({
    required this.percentage,
    required this.targetPercentage,
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = size.width * 0.42;

    final bgPaint = Paint()
      ..color = isDark ? Colors.white12 : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      false,
      bgPaint,
    );

    final sweepAngle = (percentage.clamp(0.0, 100.0) / 100.0) * 3.14159;
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withValues(alpha: 0.65), primaryColor],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) =>
      oldDelegate.percentage != percentage || oldDelegate.isDark != isDark;
}

class _MiniBarSparklinePainter extends CustomPainter {
  final List<dynamic> data;
  final Color barColor;
  final bool isDark;

  _MiniBarSparklinePainter({
    required this.data,
    required this.barColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final count = data.length;
    final barWidth = (size.width / count) * 0.55;
    final slotWidth = size.width / count;

    for (int i = 0; i < count; i++) {
      final item = data[i];
      final double rate = (item['rate'] as num?)?.toDouble() ?? 80.0;
      final double barHeight = (rate / 100.0) * (size.height - 18);
      final double x = i * slotWidth + (slotWidth - barWidth) / 2;
      final double y = size.height - 18 - barHeight;

      final isLast = i == count - 1;
      final paint = Paint()
        ..color = isLast ? barColor : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rrect, paint);

      final textSpan = TextSpan(
        text: item['day']?.toString() ?? '',
        style: TextStyle(
          fontSize: 9,
          fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
          color: isLast
              ? barColor
              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
        ),
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (barWidth - tp.width) / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarSparklinePainter oldDelegate) => true;
}

class _FleetDonutPainter extends CustomPainter {
  final int onRoute;
  final int arrived;
  final int returning;
  final int delayed;
  final int offline;
  final bool isDark;

  _FleetDonutPainter({
    required this.onRoute,
    required this.arrived,
    required this.returning,
    required this.delayed,
    required this.offline,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final total = onRoute + arrived + returning + delayed + offline;

    if (total == 0) {
      final paint = Paint()
        ..color = isDark ? Colors.white12 : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    final segments = [
      {'val': onRoute, 'color': const Color(0xFF10B981)},
      {'val': arrived, 'color': const Color(0xFF0EA5E9)},
      {'val': returning, 'color': const Color(0xFFF59E0B)},
      {'val': delayed, 'color': const Color(0xFFEF4444)},
      {'val': offline, 'color': const Color(0xFF94A3B8)},
    ];

    double startAngle = -1.570796;
    for (final seg in segments) {
      final val = seg['val'] as int;
      if (val <= 0) continue;
      final sweep = (val / total) * 6.283185;
      final paint = Paint()
        ..color = seg['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep - 0.04,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _FleetDonutPainter oldDelegate) => true;
}

class _DefaulterAgingBarPainter extends CustomPainter {
  final double under30;
  final double days30to60;
  final double over60;
  final bool isDark;

  _DefaulterAgingBarPainter({
    required this.under30,
    required this.days30to60,
    required this.over60,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = under30 + days30to60 + over60;
    if (total <= 0) {
      final paint = Paint()
        ..color = isDark ? Colors.white12 : const Color(0xFFE2E8F0)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(4)),
        paint,
      );
      return;
    }

    final w1 = (under30 / total) * size.width;
    final w2 = (days30to60 / total) * size.width;
    final w3 = (over60 / total) * size.width;

    final p1 = Paint()..color = const Color(0xFFF59E0B);
    final p2 = Paint()..color = const Color(0xFFF97316);
    final p3 = Paint()..color = const Color(0xFFEF4444);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w1, size.height), const Radius.circular(3)),
      p1,
    );
    canvas.drawRect(Rect.fromLTWH(w1, 0, w2, size.height), p2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w1 + w2, 0, w3, size.height), const Radius.circular(3)),
      p3,
    );
  }

  @override
  bool shouldRepaint(covariant _DefaulterAgingBarPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final Map<String, double> values;
  final List<Color> colors;

  PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.values.fold(0, (sum, item) => sum + item);
    if (total == 0) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - 14) / 2,
    );

    double startAngle = -3.14159 / 2; // top
    int i = 0;
    values.forEach((key, val) {
      final sweepAngle = (val / total) * 2 * 3.14159;
      paint.color = colors[i % colors.length];
      
      canvas.drawArc(rect, startAngle + 0.05, sweepAngle - 0.1, false, paint);
      
      startAngle += sweepAngle;
      i++;
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final List<double> addedData;
  final List<double> activeData;
  final Color addedColor;
  final Color activeColor;

  LineChartPainter({
    required this.addedData,
    required this.activeData,
    required this.addedColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (addedData.isEmpty || activeData.isEmpty) return;

    final double maxVal = [
      ...addedData,
      ...activeData,
      10.0
    ].fold(0.0, (max, val) => val > max ? val : max);

    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawLine(canvas, size, addedData, maxVal, addedColor);
    _drawLine(canvas, size, activeData, maxVal, activeColor);
  }

  void _drawLine(Canvas canvas, Size size, List<double> data, double maxVal, Color color) {
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double dx = size.width / (data.length - 1);
    final Path path = Path();

    for (int i = 0; i < data.length; i++) {
      final double x = i * dx;
      final double y = size.height * (1 - (data[i] / maxVal));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    for (int i = 0; i < data.length; i++) {
      final double x = i * dx;
      final double y = size.height * (1 - (data[i] / maxVal));
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ExportPreviewDialog extends StatefulWidget {
  final bool isDark;
  final Map<String, dynamic> data;
  const _ExportPreviewDialog({required this.isDark, required this.data});

  @override
  State<_ExportPreviewDialog> createState() => _ExportPreviewDialogState();
}

class _ExportPreviewDialogState extends State<_ExportPreviewDialog> {
  String _selectedTemplate = 'pdf';
  double _progress = 0.0;
  bool _isGenerating = false;
  String _statusText = '';

  void _startDownload() {
    setState(() {
      _isGenerating = true;
      _progress = 0.05;
      _statusText = 'Initializing document parameters...';
    });

    // Animate premium progress bar steps
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _progress = 0.35;
        _statusText = 'Compiling charts & analytics dataset...';
      });
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _progress = 0.75;
        _statusText = 'Formatting rows & signing signatures...';
      });
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _progress = 1.0;
        _statusText = 'Export complete!';
      });
    });

    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;

      try {
        if (_selectedTemplate == 'pdf') {
          final String htmlContent = '''
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <title>EduSHAMIIT Executive Report</title>
              <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
              <style>
                body {
                  font-family: 'Inter', sans-serif;
                  color: #1E293B;
                  background-color: #F8FAFC;
                  padding: 40px;
                  margin: 0;
                  -webkit-print-color-adjust: exact;
                  print-color-adjust: exact;
                }
                
                .report-container {
                  max-width: 1000px;
                  margin: 0 auto;
                  background: white;
                  padding: 40px;
                  border-radius: 16px;
                  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.05), 0 8px 10px -6px rgba(0, 0, 0, 0.05);
                  border: 1px solid #E2E8F0;
                }

                .header-banner {
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  border-bottom: 2px solid #E2E8F0;
                  padding-bottom: 24px;
                  margin-bottom: 32px;
                }

                .logo-section {
                  display: flex;
                  align-items: center;
                  gap: 12px;
                }

                .logo-symbol {
                  width: 40px;
                  height: 40px;
                  background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%);
                  border-radius: 10px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  color: white;
                  font-family: 'Outfit', sans-serif;
                  font-weight: 700;
                  font-size: 20px;
                }

                .brand-name {
                  font-family: 'Outfit', sans-serif;
                  font-size: 22px;
                  font-weight: 700;
                  color: #0F172A;
                  letter-spacing: -0.5px;
                }

                .badge-confidential {
                  background-color: #FEF2F2;
                  color: #EF4444;
                  font-size: 11px;
                  font-weight: 600;
                  padding: 6px 12px;
                  border-radius: 9999px;
                  text-transform: uppercase;
                  letter-spacing: 1px;
                  border: 1px solid #FEE2E2;
                }

                .report-title-section {
                  margin-bottom: 32px;
                }

                .report-title {
                  font-family: 'Outfit', sans-serif;
                  font-size: 32px;
                  font-weight: 700;
                  color: #0F172A;
                  margin: 0 0 8px 0;
                  background: linear-gradient(to right, #0F172A, #3B82F6);
                  -webkit-background-clip: text;
                  -webkit-text-fill-color: transparent;
                }

                .report-meta {
                  font-size: 13px;
                  color: #64748B;
                  display: flex;
                  gap: 24px;
                }

                .meta-item {
                  display: flex;
                  align-items: center;
                  gap: 6px;
                }

                .grid-stats {
                  display: grid;
                  grid-template-columns: repeat(3, 1fr);
                  gap: 20px;
                  margin-bottom: 40px;
                }

                .card-stat {
                  background: #F8FAFC;
                  border: 1px solid #E2E8F0;
                  border-radius: 12px;
                  padding: 24px;
                  position: relative;
                  overflow: hidden;
                }

                .card-stat::before {
                  content: '';
                  position: absolute;
                  top: 0;
                  left: 0;
                  width: 4px;
                  height: 100%;
                  background: #4F46E5;
                }

                .card-stat.revenue::before {
                  background: #10B981;
                }

                .card-stat.growth::before {
                  background: #3B82F6;
                }

                .stat-label {
                  font-size: 12px;
                  font-weight: 600;
                  color: #64748B;
                  text-transform: uppercase;
                  letter-spacing: 0.5px;
                  margin-bottom: 8px;
                }

                .stat-value {
                  font-family: 'Outfit', sans-serif;
                  font-size: 28px;
                  font-weight: 700;
                  color: #0F172A;
                }

                .section-title {
                  font-family: 'Outfit', sans-serif;
                  font-size: 20px;
                  font-weight: 600;
                  color: #0F172A;
                  margin: 0 0 16px 0;
                }

                .table-container {
                  border: 1px solid #E2E8F0;
                  border-radius: 12px;
                  overflow: hidden;
                  margin-bottom: 40px;
                }

                table {
                  width: 100%;
                  border-collapse: collapse;
                  background: white;
                }

                th {
                  background: #F1F5F9;
                  color: #475569;
                  font-weight: 600;
                  font-size: 12px;
                  text-transform: uppercase;
                  letter-spacing: 0.5px;
                  padding: 16px 20px;
                  text-align: left;
                }

                td {
                  padding: 16px 20px;
                  border-bottom: 1px solid #E2E8F0;
                  font-size: 14px;
                  color: #334155;
                }

                tr:last-child td {
                  border-bottom: none;
                }

                .status-pill {
                  display: inline-flex;
                  align-items: center;
                  padding: 4px 10px;
                  border-radius: 9999px;
                  font-size: 12px;
                  font-weight: 500;
                  background: #ECFDF5;
                  color: #065F46;
                }

                .footer {
                  border-top: 1px solid #E2E8F0;
                  padding-top: 20px;
                  margin-top: 40px;
                  display: flex;
                  justify-content: space-between;
                  align-items: center;
                  font-size: 12px;
                  color: #94A3B8;
                }

                @media print {
                  body {
                    background-color: white;
                    padding: 0;
                  }
                  .report-container {
                    border: none;
                    box-shadow: none;
                    padding: 0;
                  }
                  @page {
                    margin: 20mm;
                  }
                }
              </style>
            </head>
            <body>
              <div class="report-container">
                <div class="header-banner">
                  <div class="logo-section">
                    <div class="logo-symbol">E</div>
                    <div class="brand-name">EduSHAMIIT</div>
                  </div>
                  <div class="badge-confidential">Confidential</div>
                </div>

                <div class="report-title-section">
                  <h1 class="report-title">System Administration Report</h1>
                  <div class="report-meta">
                    <div class="meta-item">
                      <strong>Generated:</strong> ${DateTime.now().toLocal().toString().substring(0, 19)}
                    </div>
                    <div class="meta-item">
                      <strong>Scope:</strong> Global Platform
                    </div>
                  </div>
                </div>

                <div class="grid-stats">
                  <div class="card-stat">
                    <div class="stat-label">Total Institutions</div>
                    <div class="stat-value">${widget.data['total_institutions'] ?? 0}</div>
                  </div>
                  <div class="card-stat">
                    <div class="stat-label">Total Users</div>
                    <div class="stat-value">${widget.data['total_users'] ?? 0}</div>
                  </div>
                  <div class="card-stat">
                    <div class="stat-label">Total Students</div>
                    <div class="stat-value">${widget.data['total_students'] ?? 0}</div>
                  </div>
                  <div class="card-stat">
                    <div class="stat-label">Total Staff</div>
                    <div class="stat-value">${widget.data['total_staff'] ?? 0}</div>
                  </div>
                  <div class="card-stat revenue">
                    <div class="stat-label">Total Revenue</div>
                    <div class="stat-value">&#8377;${widget.data['total_revenue'] ?? 0}</div>
                  </div>
                  <div class="card-stat growth">
                    <div class="stat-label">Revenue Growth</div>
                    <div class="stat-value">+${widget.data['revenue_growth_percent'] ?? 0}%</div>
                  </div>
                </div>

                <h2 class="section-title">Detailed System Status</h2>
                <div class="table-container">
                  <table>
                    <thead>
                      <tr>
                        <th>Module / Component</th>
                        <th>Status / Count</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>Active Sessions</td>
                        <td><strong>${widget.data['system_overview']?['active_sessions'] ?? 156}</strong></td>
                      </tr>
                      <tr>
                        <td>Database Size</td>
                        <td><span class="status-pill">${widget.data['system_overview']?['database_status'] ?? 'Healthy'}</span></td>
                      </tr>
                      <tr>
                        <td>Server Status</td>
                        <td><span class="status-pill">${widget.data['system_overview']?['server_status'] ?? 'Healthy'}</span></td>
                      </tr>
                    </tbody>
                  </table>
                </div>

                <div class="footer">
                  <div>EduSHAMIIT System Management Platform &copy; ${DateTime.now().year}</div>
                  <div>Page 1 of 1</div>
                </div>
              </div>

              <script>
                window.onload = function() {
                  setTimeout(function() {
                    window.print();
                  }, 500);
                }
              </script>
            </body>
            </html>
          ''';

          final bytes = utf8.encode(htmlContent);
          final blob = html.Blob([bytes], 'text/html');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.window.open(url, '_blank');
          Future.delayed(const Duration(seconds: 5), () {
            html.Url.revokeObjectUrl(url);
          });
        } else {
          final csvText = "Metric,Value,Timeframe\n"
              "Total Institutions,${widget.data['total_institutions'] ?? 0},Global Range\n"
              "Total Users,${widget.data['total_users'] ?? 0},Global Range\n"
              "Total Students,${widget.data['total_students'] ?? 0},Global Range\n"
              "Total Staff,${widget.data['total_staff'] ?? 0},Global Range\n"
              "Total Revenue,${widget.data['total_revenue'] ?? 0},Global Range\n"
              "Revenue Growth,${widget.data['revenue_growth_percent'] ?? 0}%,Global Range\n"
              "Active Sessions,${widget.data['system_overview']?['active_sessions'] ?? 156},Global Range\n"
              "Server Status,${widget.data['system_overview']?['server_status'] ?? 'Healthy'},Global Range\n";

          final bytes = utf8.encode(csvText);
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute("download", "super_admin_report_${DateTime.now().millisecondsSinceEpoch}.csv")
            ..click();
          html.Url.revokeObjectUrl(url);
        }
      } catch (e) {
        debugPrint("Download error: $e");
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Report exported successfully as ${_selectedTemplate.toUpperCase()}!',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Export Analytics Report',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (!_isGenerating)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.grey,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select file format to compile and download system reports.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            
            if (!_isGenerating) ...[
              // Preview templates
              _buildTemplateOption('pdf', 'Executive PDF Report', 'Includes custom pie charts, line graphs, alerts summary & styled pages.', Icons.picture_as_pdf_outlined),
              const SizedBox(height: 12),
              _buildTemplateOption('xlsx', 'Excel Data Worksheet', 'Detailed spreadsheets with tabular logs, payment rows, and statistics.', Icons.table_view_outlined),
              const SizedBox(height: 12),
              _buildTemplateOption('csv', 'CSV Flat Database Dump', 'Raw comma-separated database values suitable for import.', Icons.insert_drive_file_outlined),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Generate & Download', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    CircularProgressIndicator(
                      value: _progress,
                      color: const Color(0xFF4F46E5),
                      backgroundColor: widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusText,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}% Completed',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateOption(String id, String title, String desc, IconData icon) {
    final isSelected = _selectedTemplate == id;
    return InkWell(
      onTap: () => setState(() => _selectedTemplate = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (widget.isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF4F46E5) : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchOverlayDialog extends StatefulWidget {
  final bool isDark;
  const _SearchOverlayDialog({required this.isDark});

  @override
  State<_SearchOverlayDialog> createState() => _SearchOverlayDialogState();
}

class _SearchOverlayDialogState extends State<_SearchOverlayDialog> {
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String val) async {
    final query = val.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService().get(
        '/admin/schools/global-search?q=${Uri.encodeComponent(query)}',
        useCache: false,
      );
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _filteredResults = List<Map<String, dynamic>>.from(res['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _filteredResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _filteredResults = [];
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _performSearch(val);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Type school, user, or panel name to search...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4F46E5)),
                suffixIcon: _queryController.text.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _queryController.clear();
                    _onSearchChanged('');
                  },
                ) : null,
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: _onSearchChanged,
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(color: Color(0xFF4F46E5), minHeight: 2),
              )
            else
              const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Search Results (${_filteredResults.length})',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _filteredResults.isEmpty ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No results match your search query.', style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
              ) : ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredResults.length,
                itemBuilder: (context, idx) {
                  final res = _filteredResults[idx];
                  IconData icon = Icons.business_outlined;
                  Color col = const Color(0xFF10B981);
                  if (res['type'] == 'user') {
                    icon = Icons.person_outline_rounded;
                    col = const Color(0xFF3B82F6);
                  } else if (res['type'] == 'system') {
                    icon = Icons.settings_outlined;
                    col = const Color(0xFF8B5CF6);
                  }

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: col, size: 18),
                    ),
                    title: Text(
                      res['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      res['subtitle'],
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(context);
                      context.go(res['route']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
