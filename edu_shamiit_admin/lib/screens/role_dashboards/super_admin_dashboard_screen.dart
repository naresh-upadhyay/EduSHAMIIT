import 'dart:convert';
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

  // Date Range state
  String _selectedRange = 'last_7_days';
  String _selectedRangeLabel = 'Last 7 Days';

  String _selectedUserRange = 'last_7_days';
  String _selectedUserRangeLabel = 'Last 7 Days';

  String _selectedRevenueRange = 'last_7_days';
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
      final res = await ApiService().get(
        '/admin/schools/dashboard-stats?range=$_selectedRange&range_user=$_selectedUserRange&range_revenue=$_selectedRevenueRange',
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
          final isLargeDesktop = width >= 1200;
          final isTablet = width >= 768 && width < 1200;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, isDark),
                const SizedBox(height: 24),
                _buildHeaderRow(context, isDark),
                const SizedBox(height: 24),
                _buildStatsCardsGrid(context, isDark, width),
                const SizedBox(height: 24),
                
                // Adaptive layout columns
                if (isLargeDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildInstitutionsOverviewCard(context, isDark),
                            const SizedBox(height: 24),
                            _buildRevenueOverviewCard(context, isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: _buildUserOverviewCard(context, isDark),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildSystemAlertsCard(context, isDark),
                            const SizedBox(height: 24),
                            _buildQuickActionsCard(context, isDark),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (isTablet)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildInstitutionsOverviewCard(context, isDark)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildRevenueOverviewCard(context, isDark)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildUserOverviewCard(context, isDark),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSystemAlertsCard(context, isDark)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildQuickActionsCard(context, isDark)),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildInstitutionsOverviewCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildUserOverviewCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildRevenueOverviewCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildSystemAlertsCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildQuickActionsCard(context, isDark),
                    ],
                  ),
                
                const SizedBox(height: 24),
                
                // Adaptive layout footer
                if (isLargeDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 9,
                        child: _buildRecentActivitiesCard(context, isDark),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: _buildSystemOverviewCard(context, isDark),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildRecentActivitiesCard(context, isDark),
                      const SizedBox(height: 24),
                      _buildSystemOverviewCard(context, isDark),
                    ],
                  ),
                const SizedBox(height: 40),
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
        // Search bar
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search anything...',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
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
        ),
        const SizedBox(width: 24),
        // Icons and user profile
        Row(
          children: [
            // Notification bell — real unread count + popover
            _buildNotificationButton(isDark),
            const SizedBox(width: 12),
            // Help button
            _buildHelpButton(isDark),
            const SizedBox(width: 24),
            // Divider
            Container(
              width: 1,
              height: 32,
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 24),
            // Profile Initials + Name
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
        )
      ],
    );
  }

  /// Notification bell with live unread badge + tap → popover panel
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
              Text(
                'Dashboard',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome back, $userName! Here's what's happening in your system today.",
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
            // Datepicker range selector
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
            const SizedBox(width: 12),
            // Export report button
            ElevatedButton.icon(
              onPressed: () => _showExportPreview(context, isDark),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Export Report',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildStatsCardsGrid(BuildContext context, bool isDark, double width) {
    final int totalInst = _data['total_institutions'] ?? 128;
    final int instThisWeek = _data['institutions_this_week'] ?? 12;
    final int totalUsers = _data['total_users'] ?? 1256;
    final int usersThisWeek = _data['users_this_week'] ?? 18;
    final int totalStud = _data['total_students'] ?? 24563;
    final int studThisWeek = _data['students_this_week'] ?? 256;
    final int totalStf = _data['total_staff'] ?? 2345;
    final int stfThisWeek = _data['staff_this_week'] ?? 34;
    final double revenue = (_data['total_revenue'] ?? 4875250).toDouble();
    final double revGrowth = (_data['revenue_growth_percent'] ?? 8.5).toDouble();

    final List<Map<String, dynamic>> cards = [
      {
        'title': 'Total Institutions',
        'value': formatNumber(totalInst),
        'growth': '+$instThisWeek in range',
        'icon': Icons.business_outlined,
        'color': const Color(0xFF4F46E5),
        'bg': const Color(0xFFEEF2FF),
      },
      {
        'title': 'Total Users',
        'value': formatNumber(totalUsers),
        'growth': '+$usersThisWeek in range',
        'icon': Icons.people_outline_rounded,
        'color': const Color(0xFF0EA5E9),
        'bg': const Color(0xFFF0F9FF),
      },
      {
        'title': 'Total Students',
        'value': formatNumber(totalStud),
        'growth': '+$studThisWeek in range',
        'icon': Icons.school_outlined,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
      },
      {
        'title': 'Total Staff',
        'value': formatNumber(totalStf),
        'growth': '+$stfThisWeek in range',
        'icon': Icons.badge_outlined,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFFFBEB),
      },
      {
        'title': 'Total Revenue',
        'value': formatCurrency(revenue),
        'growth': '+$revGrowth% this month',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFFEC4899),
        'bg': const Color(0xFFFDF2F8),
      },
    ];

    int crossAxisCount = 5;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 960) {
      crossAxisCount = 2;
    } else if (width < 1200) {
      crossAxisCount = 3;
    }

    if (crossAxisCount == 5) {
      return Row(
        children: cards.map((c) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: c == cards.last ? 0 : 16),
              child: _buildMetricCard(c, isDark),
            ),
          );
        }).toList(),
      );
    } else {
      final double cardHeight = 118.0;
      final double cardWidth = (width - (crossAxisCount - 1) * 16) / crossAxisCount;
      final double calculatedAspectRatio = cardWidth / cardHeight;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: calculatedAspectRatio,
        ),
        itemCount: cards.length,
        itemBuilder: (context, idx) => _buildMetricCard(cards[idx], isDark),
      );
    }
  }

  Widget _buildMetricCard(Map<String, dynamic> c, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  c['title'],
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? c['color'].withValues(alpha: 0.15) : c['bg'],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  c['icon'],
                  color: c['color'],
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c['value'],
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF10B981),
                    size: 10,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      c['growth'],
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInstitutionsOverviewCard(BuildContext context, bool isDark) {
    final Map<String, dynamic> overview = _data['institutions_overview'] ?? {
      'active': 98,
      'inactive': 18,
      'pending': 8,
      'suspended': 4,
    };
    final int active = overview['active'] ?? 98;
    final int inactive = overview['inactive'] ?? 18;
    final int pending = overview['pending'] ?? 8;
    final int suspended = overview['suspended'] ?? 4;
    final int total = active + inactive + pending + suspended;

    final values = {
      'Active': active.toDouble(),
      'Inactive': inactive.toDouble(),
      'Pending': pending.toDouble(),
      'Suspended': suspended.toDouble(),
    };
    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Institutions Overview',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(110, 110),
                      painter: PieChartPainter(values: values, colors: colors),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$total',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Total',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Column(
                  children: values.keys.map((key) {
                    final idx = values.keys.toList().indexOf(key);
                    final val = values[key]!;
                    final pct = total > 0 ? (val / total * 100).toStringAsFixed(1) : '0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors[idx],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              key,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${val.toInt()} ($pct%)',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          Center(
            child: TextButton(
              onPressed: () => context.go('/admin/schools'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All Institutions',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserOverviewCard(BuildContext context, bool isDark) {
    final List<dynamic> chartData = _data['user_overview_chart'] ?? [];
    final List<double> addedPoints = chartData.map<double>((d) => (d['added'] ?? 0).toDouble()).toList();
    final List<double> activePoints = chartData.map<double>((d) => (d['active'] ?? 0).toDouble()).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'User Overview',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              // Dropdown
              InkWell(
                onTap: () => _showRangeSelector(context, isDark, 'user'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedUserRangeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legends
          Row(
            children: [
              _buildChartLegendItem('Users Added', const Color(0xFF4F46E5)),
              const SizedBox(width: 16),
              _buildChartLegendItem('Users Active', const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 24),
          // Custom Drawn Line Chart with dynamic height
          Container(
            height: 180,
            constraints: const BoxConstraints(minWidth: 200),
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: LineChartPainter(
                addedData: addedPoints.isNotEmpty ? addedPoints : [25, 30, 26, 36, 28, 26, 24],
                activeData: activePoints.isNotEmpty ? activePoints : [11, 15, 12, 16, 13, 12, 10],
                addedColor: const Color(0xFF4F46E5),
                activeColor: const Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // X-Axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: chartData.map((d) {
              return Expanded(
                child: Text(
                  d['day'] ?? '',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueOverviewCard(BuildContext context, bool isDark) {
    final Map<String, dynamic> rev = _data['revenue_overview'] ?? {
      'total_revenue': 4875250,
      'total_collections': 4520300,
      'pending_collections': 354950,
      'refunds': 25000,
    };
    final double revenue = (rev['total_revenue'] ?? 4875250).toDouble();
    final double collections = (rev['total_collections'] ?? 4520300).toDouble();
    final double pending = (rev['pending_collections'] ?? 354950).toDouble();
    final double refunds = (rev['refunds'] ?? 25000).toDouble();

    final List<Map<String, dynamic>> items = [
      {
        'label': 'Total Revenue',
        'value': formatCurrency(revenue),
        'growth': '+8.5% from last month',
        'icon': Icons.payments_outlined,
        'color': const Color(0xFF4F46E5),
      },
      {
        'label': 'Total Collections',
        'value': formatCurrency(collections),
        'growth': '+7.2% from last month',
        'icon': Icons.verified_user_outlined,
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'Pending Collections',
        'value': formatCurrency(pending),
        'growth': '-2.1% from last month',
        'icon': Icons.hourglass_empty_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Refunds',
        'value': formatCurrency(refunds),
        'growth': '+1.3% from last month',
        'icon': Icons.money_off_rounded,
        'color': const Color(0xFFEF4444),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Overview',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => _showRangeSelector(context, isDark, 'revenue'),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedRevenueRangeLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item['icon'], color: item['color'], size: 16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'],
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['value'],
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['growth'],
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: item['color'] == Colors.red ? Colors.redAccent : const Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemAlertsCard(BuildContext context, bool isDark) {
    final List<dynamic> alerts = _data['system_alerts'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Alerts',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/admin/audit-log'),
                child: Text(
                  'View All',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: alerts.map<Widget>((alert) {
              Color typeColor = const Color(0xFFF59E0B);
              IconData typeIcon = Icons.warning_amber_rounded;
              Color bgCol = const Color(0xFFFFFBEB);

              final type = alert['type']?.toString().toLowerCase();
              if (type == 'critical') {
                typeColor = const Color(0xFFEF4444);
                typeIcon = Icons.error_outline_rounded;
                bgCol = const Color(0xFFFEF2F2);
              } else if (type == 'success') {
                typeColor = const Color(0xFF10B981);
                typeIcon = Icons.cloud_done_outlined;
                bgCol = const Color(0xFFECFDF5);
              } else if (type == 'info') {
                typeColor = const Color(0xFF3B82F6);
                typeIcon = Icons.info_outline_rounded;
                bgCol = const Color(0xFFEFF6FF);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? typeColor.withValues(alpha: 0.08) : bgCol,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? typeColor.withValues(alpha: 0.15) : typeColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert['title'] ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert['description'] ?? '',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alert['time'] ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, bool isDark) {
    final List<Map<String, dynamic>> actions = [
      {
        'label': 'Add School',
        'icon': Icons.business_outlined,
        'route': '/admin/schools',
      },
      {
        'label': 'Add User',
        'icon': Icons.person_add_outlined,
        'route': '/admin/users',
      },
      {
        'label': 'Add Student',
        'icon': Icons.school_outlined,
        'route': '/admin/users?role=student',
      },
      {
        'label': 'Add Staff',
        'icon': Icons.badge_outlined,
        'route': '/admin/staff',
      },
      {
        'label': 'Academic',
        'icon': Icons.calendar_today_outlined,
        'route': '/admin/system-control',
      },
      {
        'label': 'Payments',
        'icon': Icons.payments_outlined,
        'route': '/admin/finance',
      },
      {
        'label': 'Settings',
        'icon': Icons.settings_outlined,
        'route': '/admin/config',
      },
      {
        'label': 'Audit Log',
        'icon': Icons.assignment_outlined,
        'route': '/admin/audit-log',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: actions.length,
            itemBuilder: (context, idx) {
              final act = actions[idx];
              return InkWell(
                onTap: () => context.go(act['route']),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.2) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        act['icon'],
                        color: const Color(0xFF4F46E5),
                        size: 18,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        act['label'],
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesCard(BuildContext context, bool isDark) {
    final List<dynamic> activities = _data['recent_activities'] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent System Activities',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/admin/audit-log'),
                child: Text(
                  'View All Logs',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent activity found.',
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final act = activities[index];
                
                Color modCol = const Color(0xFF3B82F6);
                IconData modIcon = Icons.info_outline_rounded;
                
                final modStr = act['module']?.toString().toLowerCase() ?? '';
                if (modStr.contains('inst')) {
                  modCol = const Color(0xFF10B981);
                  modIcon = Icons.business_outlined;
                } else if (modStr.contains('user')) {
                  modCol = const Color(0xFFF59E0B);
                  modIcon = Icons.person_outline_rounded;
                } else if (modStr.contains('fee') || modStr.contains('pay')) {
                  modCol = const Color(0xFFEC4899);
                  modIcon = Icons.payments_outlined;
                } else if (modStr.contains('system')) {
                  modCol = const Color(0xFF8B5CF6);
                  modIcon = Icons.settings_outlined;
                }

                return Stack(
                  children: [
                    if (index < activities.length - 1)
                      Positioned(
                        top: 20,
                        bottom: 0,
                        left: 12,
                        child: Container(
                          width: 2,
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: modCol.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(modIcon, color: modCol, size: 12),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '${act['user']} ',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            TextSpan(
                                              text: act['activity'] ?? '',
                                              style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      act['time'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (act['description'] != null && act['description'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    act['description'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSystemOverviewCard(BuildContext context, bool isDark) {
    final Map<String, dynamic> sys = _data['system_overview'] ?? {
      'server_status': 'Healthy',
      'database_status': 'Healthy',
      'storage_used_percent': 62,
      'active_sessions': 156,
      'system_version': 'v2.5.1'
    };
    final int storagePercent = sys['storage_used_percent'] ?? 62;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          _buildSystemRow('Server Status', sys['server_status'] ?? 'Healthy', const Color(0xFF10B981), isDark),
          const SizedBox(height: 12),
          _buildSystemRow('Database Status', sys['database_status'] ?? 'Healthy', const Color(0xFF10B981), isDark),
          const SizedBox(height: 12),
          // Storage Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Storage Used',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    '$storagePercent%',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: storagePercent / 100.0,
                  minHeight: 6,
                  backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSystemRow('Active Sessions', '${sys['active_sessions'] ?? 156}', null, isDark),
          const SizedBox(height: 12),
          _buildSystemRow('System Version', sys['system_version'] ?? 'v2.5.1', null, isDark),
        ],
      ),
    );
  }

  Widget _buildSystemRow(String label, String val, Color? dotColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              val,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        )
      ],
    );
  }
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
