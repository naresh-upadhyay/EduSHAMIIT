import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DriverManagementTab extends StatefulWidget {
  final String? schoolId;
  final int initialTab;
  const DriverManagementTab({super.key, this.schoolId, this.initialTab = 0});

  @override
  State<DriverManagementTab> createState() => DriverManagementTabState();
}

class DriverManagementTabState extends State<DriverManagementTab> with TickerProviderStateMixin {
  // ═══════════════════ State ═══════════════════
  late TabController _tabController;
  List<dynamic> _drivers = [];
  List<dynamic> _vehicles = [];
  List<dynamic> _routes = [];
  List<dynamic> _driverDocuments = [];
  List<dynamic> _driverPerformance = [];
  List<dynamic> _driverTrainings = [];
  List<dynamic> _driverViolations = [];
  bool _isLoading = true;

  // Selected items for details panes
  dynamic _selectedDriver;
  dynamic _selectedDocument;
  dynamic _selectedTraining;
  dynamic _selectedViolation;

  // Search & Filters state (Driver List)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _licenseTypeFilter = 'All';
  String _assignmentFilter = 'All';
  int _currentPage = 1;
  int _pageSize = 10;

  // Document Filters state (License & Documents)
  final TextEditingController _docSearchController = TextEditingController();
  String _docSearchQuery = '';
  String _docDriverFilter = 'All';
  String _docTypeFilter = 'All';
  String _docStatusFilter = 'All';
  int _docCurrentPage = 1;
  int _docPageSize = 10;

  // Performance Filters state (Performance)
  String _perfDriverFilter = 'All';
  String _perfVehicleFilter = 'All';
  String _perfTimePeriod = 'This Month';
  int _perfCurrentPage = 1;
  int _perfPageSize = 10;

  // Training state & filters
  final TextEditingController _trainSearchController = TextEditingController();
  String _trainSearchQuery = '';
  String _trainStatusFilter = 'All';
  String _trainTypeFilter = 'All';
  int _trainCurrentPage = 1;
  int _trainPageSize = 10;

  // Violations state & filters
  final TextEditingController _violSearchController = TextEditingController();
  String _violSearchQuery = '';
  String _violStatusFilter = 'All';
  String _violSeverityFilter = 'All';
  int _violCurrentPage = 1;
  int _violPageSize = 10;

  // Theme Constants matching fleet management mockup
  static const _accent = Color(0xFF4F46E5);
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _gray = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF8FAFC);
  static const _cardBg = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);

  final Set<int> _loadedTabs = {};
  final Set<int> _visitedTabs = {};

  @override
  void initState() {
    super.initState();
    final initIdx = widget.initialTab.clamp(0, 4);
    _visitedTabs.add(initIdx);
    _tabController = TabController(length: 5, vsync: this, initialIndex: initIdx);
    _tabController.addListener(() {
      if (mounted && !_tabController.indexIsChanging) {
        _loadTabIfNeeded(_tabController.index);
        if (kIsWeb) {
          Future.microtask(() {
            try {
              html.window.history.replaceState(null, '', '/admin/driver-management?tab=${_tabController.index}');
              html.window.dispatchEvent(html.CustomEvent('tab_changed'));
            } catch (_) {}
          });
        }
        setState(() {});
      }
    });
    _loadTabIfNeeded(widget.initialTab.clamp(0, 4));
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _currentPage = 1;
      });
    });
    _docSearchController.addListener(() {
      setState(() {
        _docSearchQuery = _docSearchController.text;
        _docCurrentPage = 1;
      });
    });
    _trainSearchController.addListener(() {
      setState(() {
        _trainSearchQuery = _trainSearchController.text;
        _trainCurrentPage = 1;
      });
    });
    _violSearchController.addListener(() {
      setState(() {
        _violSearchQuery = _violSearchController.text;
        _violCurrentPage = 1;
      });
    });
  }

  @override
  void didUpdateWidget(DriverManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab);
      _loadTabIfNeeded(widget.initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _docSearchController.dispose();
    _trainSearchController.dispose();
    _violSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadTabIfNeeded(_tabController.index, forceReload: true);
  }

  Future<void> _loadTabIfNeeded(int tabIndex, {bool forceReload = false}) async {
    if (!mounted) return;
    if (!forceReload && _loadedTabs.contains(tabIndex)) return;

    final schoolId = widget.schoolId;
    if (_loadedTabs.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // Lazy load shared lookups (vehicles, routes, and drivers)
      await _ensureLookupsLoaded(forceReload: forceReload);

      switch (tabIndex) {
        case 0: // Drivers
          final drvEndpoint = schoolId != null ? '/transport/drivers?school_id=$schoolId' : '/transport/drivers';
          final drvRes = await ApiService().get(drvEndpoint, useCache: false);
          final rawDrivers = drvRes['data'];
          _drivers = (rawDrivers is List) ? rawDrivers : [];
          if (_drivers.isNotEmpty && _selectedDriver == null) {
            _selectedDriver = _drivers[0];
          }
          break;
        case 1: // Documents
          final docsEndpoint = schoolId != null ? '/transport/drivers/documents?school_id=$schoolId' : '/transport/drivers/documents';
          final docsRes = await ApiService().get(docsEndpoint, useCache: false);
          final rawDocs = docsRes['data'];
          _driverDocuments = (rawDocs is List) ? rawDocs : [];
          break;
        case 2: // Performance
          final perfEndpoint = schoolId != null ? '/transport/drivers/performance?school_id=$schoolId' : '/transport/drivers/performance';
          final perfRes = await ApiService().get(perfEndpoint, useCache: false);
          final rawPerf = perfRes['data'];
          _driverPerformance = (rawPerf is List) ? rawPerf : [];
          break;
        case 3: // Training
          final trainEndpoint = schoolId != null ? '/transport/drivers/training?school_id=$schoolId' : '/transport/drivers/training';
          final trainRes = await ApiService().get(trainEndpoint, useCache: false);
          final rawTrain = trainRes['data'];
          _driverTrainings = (rawTrain is List) ? rawTrain : [];
          break;
        case 4: // Violations
          final violEndpoint = schoolId != null ? '/transport/drivers/violations?school_id=$schoolId' : '/transport/drivers/violations';
          final violRes = await ApiService().get(violEndpoint, useCache: false);
          final rawViol = violRes['data'];
          _driverViolations = (rawViol is List) ? rawViol : [];
          break;
      }
      _loadedTabs.add(tabIndex);
    } catch (e) {
      debugPrint('Error loading tab $tabIndex: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureLookupsLoaded({bool forceReload = false}) async {
    if (!forceReload && _vehicles.isNotEmpty && _routes.isNotEmpty && _drivers.isNotEmpty) {
      return;
    }
    final schoolId = widget.schoolId;
    try {
      final drvEndpoint = schoolId != null ? '/transport/drivers?school_id=$schoolId' : '/transport/drivers';
      final lookups = await Future.wait([
        (_vehicles.isEmpty || forceReload) ? ApiService().get('/transport/vehicles?page_size=100', useCache: !forceReload) : Future.value(null),
        (_routes.isEmpty || forceReload) ? ApiService().get('/transport/routes?page_size=100', useCache: !forceReload) : Future.value(null),
        (_drivers.isEmpty || forceReload) ? ApiService().get(drvEndpoint, useCache: !forceReload) : Future.value(null),
      ]);

      final vRes = lookups[0];
      if (vRes != null) {
        final rawVehicles = vRes['data'];
        if (rawVehicles is Map && rawVehicles['vehicles'] is List) {
          _vehicles = rawVehicles['vehicles'] as List;
        } else if (rawVehicles is List) {
          _vehicles = rawVehicles;
        }
      }

      final rRes = lookups[1];
      if (rRes != null) {
        final rawRoutes = rRes['data'];
        _routes = (rawRoutes is List) ? rawRoutes : [];
      }

      final dRes = lookups[2];
      if (dRes != null) {
        final rawDrivers = dRes['data'];
        if (rawDrivers is List) {
          _drivers = rawDrivers;
        } else if (rawDrivers is Map && rawDrivers['drivers'] is List) {
          _drivers = rawDrivers['drivers'] as List;
        }
        if (_drivers.isNotEmpty && _selectedDriver == null) {
          _selectedDriver = _drivers[0];
        }
      }
    } catch (e) {
      debugPrint('Lookup load error: $e');
    }
  }

  // ═══════════════════ Document File Download ═══════════════════
  void _downloadDocumentFile(dynamic doc) {
    if (doc == null) return;
    final fileName = (doc['file_name'] ?? '${doc['document_type'] ?? "document"}.pdf').toString();
    final fileUrl = doc['file_url']?.toString();

    if (fileUrl != null && fileUrl.trim().isNotEmpty && (fileUrl.startsWith('http://') || fileUrl.startsWith('https://') || fileUrl.startsWith('data:'))) {
      try {
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = fileUrl
          ..style.display = 'none'
          ..target = '_blank'
          ..download = fileName;
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
      } catch (_) {
        html.window.open(fileUrl, '_blank');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $fileName...'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generate and trigger download for PDF document containing document details
    try {
      final drv = doc['drivers'] ?? {};
      final drvName = (drv['name'] ?? 'Driver').toString();
      final docType = (doc['document_type'] ?? 'Official Document').toString();
      final docNo = (doc['document_no'] ?? '—').toString();
      final issueDate = _formatDate(doc['issued_date']);
      final expiryDate = _formatDate(doc['expiry_date']);
      final authority = (doc['issuing_authority'] ?? 'Transport Department').toString();
      final status = (doc['status'] ?? 'Valid').toString();
      final effectiveFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';

      final content = '''
================================================================================
                        EDUSHAMIIT FLEET MANAGEMENT
                        OFFICIAL DRIVER DOCUMENT
================================================================================

Driver Name:          $drvName
Document Type:        $docType
Document Number:      $docNo
Issue Date:           $issueDate
Expiry Date:          $expiryDate
Issuing Authority:    $authority
Verification Status:  $status

--------------------------------------------------------------------------------
This is an official digital record copy of the driver document.
Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}
================================================================================
''';

      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = effectiveFileName;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded PDF: $effectiveFileName'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download document: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helper date selection
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // ═══════════════════ Filter Getter ═══════════════════
  List<dynamic> get _filteredDrivers {
    return _drivers.where((driver) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (driver['name'] ?? '').toLowerCase();
        final code = (driver['driver_code'] ?? '').toLowerCase();
        final phone = (driver['phone'] ?? '').toLowerCase();
        final lic = (driver['license_no'] ?? '').toLowerCase();
        if (!name.contains(query) && !code.contains(query) && !phone.contains(query) && !lic.contains(query)) {
          return false;
        }
      }

      // 2. Status Filter
      if (_statusFilter != 'All') {
        final status = driver['status'] ?? 'Inactive';
        if (status.toString().toLowerCase() != _statusFilter.toLowerCase()) {
          return false;
        }
      }

      // 3. Category (License Type) Filter
      if (_licenseTypeFilter != 'All') {
        final type = driver['license_type'] ?? 'LMV';
        if (type.toString().toLowerCase() != _licenseTypeFilter.toLowerCase()) {
          return false;
        }
      }

      // 4. Assignment Filter
      if (_assignmentFilter != 'All') {
        final isAssigned = driver['assigned_vehicle_id'] != null;
        if (_assignmentFilter == 'Assigned' && !isAssigned) return false;
        if (_assignmentFilter == 'Unassigned' && isAssigned) return false;
      }

      return true;
    }).toList();
  }



  List<dynamic> get _filteredTrainings {
    return _driverTrainings.where((train) {
      // 1. Search Query
      if (_trainSearchQuery.isNotEmpty) {
        final query = _trainSearchQuery.toLowerCase();
        final drv = train['drivers'] ?? {};
        final name = (drv['name'] ?? '').toLowerCase();
        final prog = (train['training_program'] ?? '').toLowerCase();
        if (!name.contains(query) && !prog.contains(query)) {
          return false;
        }
      }

      // 2. Status Filter
      if (_trainStatusFilter != 'All') {
        if (train['status'] != _trainStatusFilter) {
          return false;
        }
      }

      // 3. Type Filter
      if (_trainTypeFilter != 'All') {
        if (train['training_type'] != _trainTypeFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<dynamic> get _filteredViolations {
    return _driverViolations.where((viol) {
      // 1. Search Query
      if (_violSearchQuery.isNotEmpty) {
        final query = _violSearchQuery.toLowerCase();
        final drv = viol['drivers'] ?? {};
        final name = (drv['name'] ?? '').toLowerCase();
        final type = (viol['violation_type'] ?? '').toLowerCase();
        if (!name.contains(query) && !type.contains(query)) {
          return false;
        }
      }

      // 2. Status Filter
      if (_violStatusFilter != 'All') {
        if (viol['status'] != _violStatusFilter) {
          return false;
        }
      }

      // 3. Severity Filter
      if (_violSeverityFilter != 'All') {
        if (viol['severity'] != _violSeverityFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ═══════════════════ build ═══════════════════
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _buildHeader() {
    String title = 'Driver List';
    String desc = 'Manage driver information, profiles, licenses, and performance.';

    switch (_tabController.index) {
      case 0:
        title = 'Driver List';
        desc = 'Manage driver information, profiles, licenses, and performance.';
        break;
      case 1:
        title = 'License & Documents';
        desc = 'Track driver licenses, badges, medical certificates, and expiry dates.';
        break;
      case 2:
        title = 'Driver Performance';
        desc = 'Monitor driver behavior, safety ratings, and performance metrics.';
        break;
      case 3:
        title = 'Training & Certifications';
        desc = 'Manage driver training programs, safety certifications, and retrainings.';
        break;
      case 4:
        title = 'Violations & Incidents';
        desc = 'Log, review, and track traffic violations and incident reports.';
        break;
    }

    final now = DateTime.now();
    final dateStr = 'Today, ${now.day} ${_getMonthName(now.month)} ${now.year}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════ build ═══════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_accent)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isDesktop = availableWidth >= 1100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 20),

            // Floating custom TabBar Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTabBar(),
            ),
            const SizedBox(height: 16),

            // Tab content switcher
            Expanded(
              child: _buildTabContent(isDesktop, availableWidth),
            ),
          ],
        );
      },
    );
  }

  // Custom Floating TabBar Widget
  Widget _buildTabBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (_tabController.index != index) {
              _tabController.animateTo(index);
            }
          },
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelColor: const Color(0xFF4F46E5), // Indigo 600
          unselectedLabelColor: const Color(0xFF475569), // Slate 600
          indicatorColor: const Color(0xFF4F46E5),
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            _buildTabItem(Icons.person_outline_rounded, 'Driver List'),
            _buildTabItem(Icons.description_outlined, 'License & Documents'),
            _buildTabItem(Icons.speed_rounded, 'Performance'),
            _buildTabItem(Icons.school_outlined, 'Training'),
            _buildTabItem(Icons.warning_amber_rounded, 'Violations'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDesktop, double availableWidth) {
    final activeIdx = _tabController.index.clamp(0, 4);
    _visitedTabs.add(activeIdx);

    return IndexedStack(
      index: activeIdx,
      children: [
        _visitedTabs.contains(0) ? _buildDriverListTab(isDesktop, availableWidth) : const SizedBox.shrink(),
        _visitedTabs.contains(1) ? _buildLicenseDocumentsTab(availableWidth) : const SizedBox.shrink(),
        _visitedTabs.contains(2) ? _buildPerformanceTab(availableWidth) : const SizedBox.shrink(),
        _visitedTabs.contains(3) ? _buildTrainingTab(availableWidth) : const SizedBox.shrink(),
        _visitedTabs.contains(4) ? _buildViolationsTab(availableWidth) : const SizedBox.shrink(),
      ],
    );
  }

  // ─────── Tab 0: Driver List split view ───────
  Widget _buildDriverListTab(bool isDesktop, double availableWidth) {
    // Stats calculation
    final totalDrivers = _drivers.length;
    final activeCount = _drivers.where((d) => ['active', 'on duty', 'on leave'].contains((d['status'] ?? '').toLowerCase())).length;
    final onDutyCount = _drivers.where((d) => (d['status'] ?? '').toLowerCase() == 'on duty').length;
    final onLeaveCount = _drivers.where((d) => (d['status'] ?? '').toLowerCase() == 'on leave').length;
    final inactiveCount = _drivers.where((d) => (d['status'] ?? '').toLowerCase() == 'inactive').length;

    final activePct = totalDrivers > 0 ? (activeCount / totalDrivers * 100) : 0.0;
    final onDutyPct = totalDrivers > 0 ? (onDutyCount / totalDrivers * 100) : 0.0;
    final onLeavePct = totalDrivers > 0 ? (onLeaveCount / totalDrivers * 100) : 0.0;
    final inactivePct = totalDrivers > 0 ? (inactiveCount / totalDrivers * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Responsive Grid KPI Row
          _buildKpiSection([
            _buildKpiCard('Total Drivers', '$totalDrivers', 'All drivers', const Color(0xFF8B5CF6), Icons.people_outline),
            _buildKpiCard('Active Drivers', '$activeCount', '${activePct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.verified_user_outlined, _green),
            _buildKpiCard('On Duty', '$onDutyCount', '${onDutyPct.toStringAsFixed(2)}%', const Color(0xFFF59E0B), Icons.directions_bus_filled_outlined, _orange),
            _buildKpiCard('On Leave', '$onLeaveCount', '${onLeavePct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.time_to_leave_outlined, _red),
            _buildKpiCard('Inactive Drivers', '$inactiveCount', '${inactivePct.toStringAsFixed(2)}%', const Color(0xFF94A3B8), Icons.block_flipped, _gray),
          ]),
          const SizedBox(height: 20),

          // 2. Filters & Grid Content Section
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _selectedDriver != null ? 65 : 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFiltersSection(availableWidth),
                        _buildTableSection(),
                      ],
                    ),
                  ),
                ),
                if (_selectedDriver != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 35,
                    child: _buildDetailsPanelSection(),
                  ),
                ],
              ],
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFiltersSection(availableWidth),
                  _buildTableSection(),
                ],
              ),
            ),
            if (_selectedDriver != null) ...[
              const SizedBox(height: 16),
              _buildDetailsPanelSection(),
            ],
          ],
        ],
      ),
    );
  }

  // ═══════════════════ KPI Section Grid ═══════════════════
  Widget _buildKpiSection(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 5;
        if (width < 640) {
          columns = 1;
        } else if (width < 960) {
          columns = 2;
        } else if (width < 1300) {
          columns = 3;
        }
        final cardWidth = (width - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
        );
      },
    );
  }

  // ═══════════════════ KPI Card Widget ═══════════════════
  Widget _buildKpiCard(String title, String value, String subtitle, Color color, IconData icon, [Color? valueColor, double? width]) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: valueColor ?? _textSecondary),
                        overflow: TextOverflow.ellipsis,
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

  // ═══════════════════ Shared Uniform UI Helpers ═══════════════════
  static const double _kCtrlH = 36;
  static final BorderRadius _kRadius = BorderRadius.circular(8);

  /// Uniform 36px-tall dropdown — replaces DropdownButtonFormField everywhere
  Widget _uDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return Container(
      height: _kCtrlH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _kRadius,
        border: Border.all(color: _border),
      ),
      padding: EdgeInsets.only(left: prefixIcon != null ? 8 : 12, right: 4),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _textSecondary),
                style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uniform 36px-tall search field
  Widget _uSearch({required TextEditingController controller, String hint = 'Search...'}) {
    return Container(
      height: _kCtrlH,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: _kRadius,
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: _textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uniform 36px primary button (accent / custom colour)
  Widget _uBtn({required String label, required IconData icon, required VoidCallback onPressed, Color? color}) {
    return SizedBox(
      height: _kCtrlH,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? _accent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: _kRadius),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          fixedSize: Size.fromHeight(_kCtrlH),
        ),
      ),
    );
  }

  /// Uniform 36px reset button (outlined)
  Widget _uResetBtn(VoidCallback onPressed) {
    return SizedBox(
      height: _kCtrlH,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.filter_list_rounded, size: 15),
        label: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _textSecondary,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: _kRadius),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          fixedSize: Size.fromHeight(_kCtrlH),
        ),
      ),
    );
  }

  /// Uniform 36x36 refresh icon button
  Widget _uRefreshBtn(VoidCallback onPressed, [String tooltip = 'Refresh']) {
    return SizedBox(
      width: _kCtrlH,
      height: _kCtrlH,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: _kRadius, side: const BorderSide(color: _border)),
        child: InkWell(
          borderRadius: _kRadius,
          onTap: onPressed,
          child: Center(child: Icon(Icons.refresh_rounded, size: 18, color: _textSecondary)),
        ),
      ),
    );
  }

  /// Uniform DataColumn header
  DataColumn _dataCol(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: _textSecondary, letterSpacing: 0.2),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  /// Compact 30x30 action icon button for table rows
  Widget _actionBtn(IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 14,
        constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
      ),
    );
  }

  // ═══════════════════ Tab 0 Filters Row ═══════════════════
  Widget _buildFiltersSection(double availableWidth) {
    final searchField = _uSearch(controller: _searchController, hint: 'Search by name, phone, license...');

    final statusFilter = _uDropdown(
      value: _statusFilter,
      items: ['All', 'On Duty', 'On Leave', 'Inactive', 'Active'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _statusFilter = val!; _currentPage = 1; }),
    );

    final categoryFilter = _uDropdown(
      value: _licenseTypeFilter,
      items: ['All', 'LMV', 'HMV'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Categories' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _licenseTypeFilter = val!; _currentPage = 1; }),
    );

    final assignmentFilter = _uDropdown(
      value: _assignmentFilter,
      items: ['All', 'Assigned', 'Unassigned'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Assignments' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _assignmentFilter = val!; _currentPage = 1; }),
    );

    final resetButton = _uResetBtn(() {
      setState(() {
        _searchController.clear();
        _statusFilter = 'All';
        _licenseTypeFilter = 'All';
        _assignmentFilter = 'All';
        _currentPage = 1;
      });
    });

    final refreshButton = _uRefreshBtn(_loadData, 'Refresh Drivers Data');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w >= 900) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                SizedBox(width: 130, child: statusFilter),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: categoryFilter),
                const SizedBox(width: 8),
                SizedBox(width: 150, child: assignmentFilter),
                const SizedBox(width: 8),
                resetButton,
                const SizedBox(width: 6),
                refreshButton,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 130, child: statusFilter),
                  SizedBox(width: 140, child: categoryFilter),
                  SizedBox(width: 150, child: assignmentFilter),
                  resetButton,
                  refreshButton,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════ Data Table ═══════════════════
  Widget _buildTableSection() {
    final filtered = _filteredDrivers;
    final totalCount = filtered.length;
    final startIndex = (_currentPage - 1) * _pageSize;
    final paginated = filtered.skip(startIndex).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1000),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              horizontalMargin: 16,
              columnSpacing: 20,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columns: [
                _dataCol('Driver'),
                _dataCol('License'),
                _dataCol('Contact'),
                _dataCol('Exp.'),
                _dataCol('Status'),
                _dataCol('Assignment'),
                _dataCol('Actions'),
              ],
              rows: paginated.map((dev) {
                final isSelected = _selectedDriver != null && _selectedDriver['id'] == dev['id'];
                final status = (dev['status'] ?? 'Inactive').toString();
                final experience = '${dev['experience_years'] ?? 0} Yrs';

                // Status chip styling
                Color statusColor;
                Color statusBg;
                switch (status.toLowerCase()) {
                  case 'on duty':
                    statusColor = _green;
                    statusBg = _green.withValues(alpha: 0.12);
                    break;
                  case 'on leave':
                    statusColor = _orange;
                    statusBg = _orange.withValues(alpha: 0.12);
                    break;
                  case 'inactive':
                    statusColor = _gray;
                    statusBg = _gray.withValues(alpha: 0.12);
                    break;
                  default:
                    statusColor = _blue;
                    statusBg = _blue.withValues(alpha: 0.12);
                }

                // Assignment details
                final veh = dev['bus_routes'];
                final vehicleText = veh != null ? (veh['registration_no'] ?? veh['bus_number'] ?? 'Assigned') : '—';
                final vehicleType = veh != null ? (veh['vehicle_type'] ?? 'Bus') : '';

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      _selectedDriver = dev;
                    });
                  },
                  cells: [
                    // Driver info
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _accent.withValues(alpha: 0.1),
                              backgroundImage: dev['photo_url'] != null ? NetworkImage(dev['photo_url']) : null,
                              child: dev['photo_url'] == null 
                                ? Text(dev['name'].toString().substring(0, 1).toUpperCase(), style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold, fontSize: 13))
                                : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dev['name'] ?? 'Driver', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary), overflow: TextOverflow.ellipsis),
                                  Text(dev['driver_code'] ?? 'Code', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // License info
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dev['license_no'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            Text(dev['license_type'] ?? '—', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Contact
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dev['phone'] ?? '—', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                            Text(dev['email'] ?? '—', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Experience
                    DataCell(
                      SizedBox(
                        width: 90,
                        child: Text(experience, style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    ),
                    // Status
                    DataCell(
                      SizedBox(
                        width: 95,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status.toLowerCase() != 'inactive') ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                status,
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Assignment
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(vehicleText, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            if (vehicleType.isNotEmpty)
                              Text(vehicleType, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 16, color: _textSecondary),
                            onPressed: () {
                              setState(() {
                                _selectedDriver = dev;
                              });
                              if (MediaQuery.of(context).size.width < 1100) {
                                _showDriverDetailsDialog(dev);
                              }
                            },
                            tooltip: 'View Details',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16, color: _accent),
                            onPressed: () => showEditDriverDialog(dev),
                            tooltip: 'Edit Driver',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                            onPressed: () => _deleteDriver(dev),
                            tooltip: 'Delete Driver',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        _buildPaginationRow(
          totalCount,
          startIndex,
          paginated.length,
          _pageSize,
          _currentPage,
          (newPage) => setState(() => _currentPage = newPage),
          (newSize) => setState(() {
            _pageSize = newSize;
            _currentPage = 1;
          }),
        ),
      ],
    );
  }

  // ═══════════════════ Details Panel ═══════════════════
  Widget _buildDetailsPanelSection() {
    final dev = _selectedDriver;
    if (dev == null) return Container();

    final status = (dev['status'] ?? 'Inactive').toString();
    Color statusColor;
    Color statusBg;
    switch (status.toLowerCase()) {
      case 'on duty':
        statusColor = _green;
        statusBg = _green.withValues(alpha: 0.12);
        break;
      case 'on leave':
        statusColor = _orange;
        statusBg = _orange.withValues(alpha: 0.12);
        break;
      case 'inactive':
        statusColor = _gray;
        statusBg = _gray.withValues(alpha: 0.12);
        break;
      default:
        statusColor = _blue;
        statusBg = _blue.withValues(alpha: 0.12);
    }

    final veh = dev['bus_routes'];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Status
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _accent.withValues(alpha: 0.1),
                backgroundImage: dev['photo_url'] != null ? NetworkImage(dev['photo_url']) : null,
                child: dev['photo_url'] == null 
                  ? Text(dev['name'].toString().substring(0, 1).toUpperCase(), style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold, fontSize: 22))
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dev['name'] ?? 'Driver', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                    const SizedBox(height: 2),
                    Text(dev['driver_code'] ?? 'Code', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: _textSecondary),
                onPressed: () => setState(() => _selectedDriver = null),
                tooltip: 'Close details panel',
              ),
            ],
          ),
          const Divider(height: 32),

          // Contact Info
          _buildDetailRow('Phone', dev['phone'] ?? '—'),
          _buildDetailRow('Email', dev['email'] ?? '—'),
          _buildDetailRow('Joined Date', _formatDate(dev['joined_date'])),
          const SizedBox(height: 16),

          // License Section
          Text('License Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
            child: Column(
              children: [
                _buildDetailRow('License Number', dev['license_no'] ?? '—'),
                _buildDetailRow('License Type', dev['license_type'] ?? '—'),
                _buildDetailRow('Issue Date', _formatDate(dev['license_issue_date'])),
                _buildDetailRow('Expiry Date', _formatDate(dev['license_expiry_date'])),
                _buildDetailRow('Authority', dev['issuing_authority'] ?? '—'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: _green, size: 14),
                    const SizedBox(width: 6),
                    Text('License is valid', style: GoogleFonts.inter(fontSize: 11, color: _green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Personal Section
          Text('Other Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          _buildDetailRow('Date of Birth', _formatDate(dev['date_of_birth'])),
          _buildDetailRow('Experience', '${dev['experience_years'] ?? 0} Years'),
          _buildDetailRow('Blood Group', dev['blood_group'] ?? '—'),
          _buildDetailRow('Aadhar Number', dev['aadhar_no'] ?? '—'),
          _buildDetailRow('Address', dev['address'] ?? '—'),
          const Divider(height: 32),

          // Assigned vehicle details
          Text('Current Assignment', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          if (veh != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _accent.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: _accent.withValues(alpha: 0.2))),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus_outlined, color: _accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(veh['registration_no'] ?? 'Assigned Vehicle', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                        Text(veh['vehicle_type'] ?? 'Bus', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Navigating to vehicle live dashboard...'), backgroundColor: _accent),
                      );
                    },
                    child: Text('View Vehicle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _accent)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text('Unassigned', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening Full Profile...'), backgroundColor: _accent),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('View Full Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => showEditDriverDialog(dev),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Edit Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? _textPrimary),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────── Tab 1: License & Documents view ───────
  Widget _buildLicenseDocumentsTab(double availableWidth) {
    // 1. Get filtered list of documents
    final filteredDocs = _driverDocuments.where((doc) {
      if (_docSearchQuery.isNotEmpty) {
        final query = _docSearchQuery.toLowerCase();
        final drvName = (doc['drivers']?['name'] ?? '').toLowerCase();
        final docType = (doc['document_type'] ?? '').toLowerCase();
        if (!drvName.contains(query) && !docType.contains(query)) return false;
      }
      if (_docDriverFilter != 'All') {
        final drvName = doc['drivers']?['name'] ?? '';
        if (drvName != _docDriverFilter) return false;
      }
      if (_docTypeFilter != 'All') {
        final type = doc['document_type'] ?? '';
        if (type != _docTypeFilter) return false;
      }
      if (_docStatusFilter != 'All') {
        final status = doc['status'] ?? 'Valid';
        if (status.toString().toLowerCase() != _docStatusFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();

    // 2. Summary stats from ALL documents
    final totalDocs = _driverDocuments.length;
    final validDocs = _driverDocuments.where((d) => ['valid', 'permanent'].contains(d['status']?.toString().toLowerCase())).length;
    final expiringDocs = _driverDocuments.where((d) => d['status']?.toString().toLowerCase() == 'expiring soon').length;
    final expiredDocs = _driverDocuments.where((d) => d['status']?.toString().toLowerCase() == 'expired').length;
    
    // Drivers with all valid docs
    final allDriverIds = _drivers.map((d) => d['id']).toSet();
    int driversWithAllValid = 0;
    for (final drvId in allDriverIds) {
      final drvDocs = _driverDocuments.where((d) => d['driver_id'] == drvId);
      final hasIssues = drvDocs.any((d) => ['expired', 'expiring soon'].contains(d['status']?.toString().toLowerCase()));
      if (drvDocs.isNotEmpty && !hasIssues) {
        driversWithAllValid++;
      }
    }

    final validPct = totalDocs > 0 ? (validDocs / totalDocs * 100) : 0.0;
    final expiringPct = totalDocs > 0 ? (expiringDocs / totalDocs * 100) : 0.0;
    final expiredPct = totalDocs > 0 ? (expiredDocs / totalDocs * 100) : 0.0;
    final driversAllValidPct = _drivers.isNotEmpty ? (driversWithAllValid / _drivers.length * 100) : 0.0;

    final bool isDesktop = availableWidth > 1100;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards grid
          _buildKpiSection([
            _buildKpiCard('Total Documents', '$totalDocs', 'All Documents', const Color(0xFF8B5CF6), Icons.description_outlined),
            _buildKpiCard('Valid Documents', '$validDocs', '${validPct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.verified_user_outlined, _green),
            _buildKpiCard('Expiring Soon (30 Days)', '$expiringDocs', '${expiringPct.toStringAsFixed(2)}%', const Color(0xFFF59E0B), Icons.warning_amber_rounded, _orange),
            _buildKpiCard('Expired Documents', '$expiredDocs', '${expiredPct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.cancel_outlined, _red),
            _buildKpiCard('Drivers with All Valid Docs', '$driversWithAllValid', '${driversAllValidPct.toStringAsFixed(2)}%', const Color(0xFF3B82F6), Icons.people_outline, _blue),
          ]),
          const SizedBox(height: 20),

          // Main split view / stacked layout
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _selectedDocument != null ? 65 : 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDocFiltersSection(availableWidth),
                        _buildDocTableSection(filteredDocs, availableWidth),
                      ],
                    ),
                  ),
                ),
                if (_selectedDocument != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 35,
                    child: _buildDocDetailsPanelSection(),
                  ),
                ],
              ],
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDocFiltersSection(availableWidth),
                  _buildDocTableSection(filteredDocs, availableWidth),
                ],
              ),
            ),
            if (_selectedDocument != null) ...[
              const SizedBox(height: 16),
              _buildDocDetailsPanelSection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDocFiltersSection(double availableWidth) {
    final driverNames = _drivers.map((d) => (d['name'] ?? '').toString()).toSet().toList();
    driverNames.sort();

    final docTypes = [
      'Driving License', 'Badge', 'Police Verification', 'Aadhaar Card',
      'Medical Certificate', 'Fitness Certificate', 'Pollution Certificate', 'PAN Card'
    ];

    final searchField = _uSearch(controller: _docSearchController, hint: 'Search driver or document...');

    final driverFilter = _uDropdown(
      value: _docDriverFilter,
      items: ['All', ...driverNames].map((drv) => DropdownMenuItem(value: drv, child: Text(drv == 'All' ? 'All Drivers' : (drv.length > 16 ? '${drv.substring(0, 14)}…' : drv), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _docDriverFilter = val!; _docCurrentPage = 1; }),
    );

    final typeFilter = _uDropdown(
      value: _docTypeFilter,
      items: ['All', ...docTypes].map((t) => DropdownMenuItem(value: t, child: Text(t == 'All' ? 'All Types' : t, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _docTypeFilter = val!; _docCurrentPage = 1; }),
    );

    final statusFilter = _uDropdown(
      value: _docStatusFilter,
      items: ['All', 'Valid', 'Expiring Soon', 'Expired', 'Permanent'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _docStatusFilter = val!; _docCurrentPage = 1; }),
    );

    final resetButton = _uResetBtn(() {
      setState(() {
        _docSearchController.clear();
        _docSearchQuery = '';
        _docDriverFilter = 'All';
        _docTypeFilter = 'All';
        _docStatusFilter = 'All';
        _docCurrentPage = 1;
      });
    });

    final refreshButton = _uRefreshBtn(_loadData, 'Refresh Documents');

    final viewAllBtn = SizedBox(
      height: _kCtrlH,
      child: OutlinedButton.icon(
        onPressed: () {
          final drvId = _docDriverFilter != 'All' ? _docDriverFilter : null;
          _showAllDocumentsModal(filterDriverId: drvId);
        },
        icon: const Icon(Icons.list_alt, size: 15),
        label: Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: _kRadius),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          fixedSize: Size.fromHeight(_kCtrlH),
        ),
      ),
    );

    final uploadBtn = _uBtn(label: 'Upload', icon: Icons.cloud_upload_outlined, onPressed: () => _showDocumentFormDialog(null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w >= 960) {
            return Row(
              children: [
                SizedBox(width: 200, child: searchField),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: driverFilter),
                const SizedBox(width: 8),
                SizedBox(width: 155, child: typeFilter),
                const SizedBox(width: 8),
                SizedBox(width: 130, child: statusFilter),
                const SizedBox(width: 8),
                resetButton,
                const SizedBox(width: 6),
                refreshButton,
                const Spacer(),
                viewAllBtn,
                const SizedBox(width: 8),
                uploadBtn,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: 140, child: driverFilter),
                  SizedBox(width: 155, child: typeFilter),
                  SizedBox(width: 130, child: statusFilter),
                  resetButton,
                  refreshButton,
                  viewAllBtn,
                  uploadBtn,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDocTableSection(List<dynamic> docs, double availableWidth) {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (docs.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description_outlined, color: _textSecondary, size: 36),
              const SizedBox(height: 12),
              Text('No documents found', style: GoogleFonts.inter(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final totalCount = docs.length;
    final startIndex = (_docCurrentPage - 1) * _docPageSize;
    final paginated = docs.skip(startIndex).take(_docPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: math.max(availableWidth, 1000)),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dividerThickness: 1.0,
              columnSpacing: 20,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columns: [
                _dataCol('Driver'),
                _dataCol('Type'),
                _dataCol('Doc No.'),
                _dataCol('Issued'),
                _dataCol('Expiry'),
                _dataCol('Status'),
                _dataCol('Days Left'),
                _dataCol('Actions'),
              ],
              rows: paginated.map((doc) {
                final drv = doc['drivers'] ?? {};
                final drvName = drv['name'] ?? 'Driver';
                final drvCode = drv['driver_code'] ?? '';
                final isSelected = _selectedDocument != null && _selectedDocument['id'] == doc['id'];

                final String docType = doc['document_type'] ?? 'Driving License';
                final String docNo = doc['document_no'] ?? '—';
                final String issueDate = _formatDate(doc['issued_date']);
                final String expiryDate = _formatDate(doc['expiry_date']);

                final status = (doc['status'] ?? 'Valid').toString();
                Color statusColor;
                Color statusBg;
                String daysLeftStr = '—';
                Color daysLeftColor = _textPrimary;

                switch (status.toLowerCase()) {
                  case 'valid':
                    statusColor = _green;
                    statusBg = _green.withValues(alpha: 0.12);
                    break;
                  case 'expiring soon':
                    statusColor = _orange;
                    statusBg = _orange.withValues(alpha: 0.12);
                    break;
                  case 'expired':
                    statusColor = _red;
                    statusBg = _red.withValues(alpha: 0.12);
                    break;
                  case 'permanent':
                    statusColor = _blue;
                    statusBg = _blue.withValues(alpha: 0.12);
                    break;
                  default:
                    statusColor = _blue;
                    statusBg = _blue.withValues(alpha: 0.12);
                }

                // Days left computation
                if (status.toLowerCase() == 'permanent') {
                  daysLeftStr = 'Permanent';
                  daysLeftColor = _blue;
                } else if (doc['expiry_date'] != null) {
                  try {
                    final expiry = DateTime.parse(doc['expiry_date']);
                    final diff = expiry.difference(DateTime.now()).inDays;
                    if (diff < 0) {
                      daysLeftStr = '${diff.abs()} Days Overdue';
                      daysLeftColor = _red;
                    } else {
                      daysLeftStr = '$diff Days';
                      daysLeftColor = diff <= 30 ? _red : (diff <= 90 ? _orange : _green);
                    }
                  } catch (_) {}
                }

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      _selectedDocument = doc;
                    });
                  },
                  cells: [
                    // Driver
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                            child: drv['photo_url'] == null 
                              ? Text(drvName.substring(0, 1).toUpperCase(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _accent))
                              : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(drvName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
                              Text(drvCode, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Document Type
                    DataCell(Text(docType, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
                    // Document Number
                    DataCell(Text(docNo, style: GoogleFonts.inter(fontSize: 12))),
                    // Issue Date
                    DataCell(Text(issueDate, style: GoogleFonts.inter(fontSize: 12))),
                    // Expiry Date
                    DataCell(Text(doc['expiry_date'] != null ? expiryDate : '—', style: GoogleFonts.inter(fontSize: 12))),
                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(16)),
                        child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Days Left
                    DataCell(Text(daysLeftStr, style: GoogleFonts.inter(fontSize: 12, color: daysLeftColor, fontWeight: FontWeight.bold))),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            onPressed: () {
                              setState(() => _selectedDocument = doc);
                              if (availableWidth <= 1100) {
                                // On small screens, show dialog details
                                _showDocumentDetailsDialog(doc);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_outlined, size: 18, color: _accent),
                            onPressed: () => _downloadDocumentFile(doc),
                            tooltip: 'Download Document PDF',
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showDocumentFormDialog(doc);
                              } else if (val == 'delete') {
                                _deleteDocument(doc);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Document')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: _red), SizedBox(width: 8), Text('Delete Document')])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        _buildPaginationRow(
          totalCount,
          startIndex,
          paginated.length,
          _docPageSize,
          _docCurrentPage,
          (newPage) => setState(() => _docCurrentPage = newPage),
          (newSize) => setState(() {
            _docPageSize = newSize;
            _docCurrentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildDocDetailsPanelSection() {
    final doc = _selectedDocument;
    if (doc == null) return Container();

    final drv = doc['drivers'] ?? {};
    final drvName = drv['name'] ?? 'Driver';
    final drvCode = drv['driver_code'] ?? '';

    // Calculate selected driver's documents counts for Donut Chart
    final driverId = doc['driver_id'];
    final driverDocs = _driverDocuments.where((d) => d['driver_id'] == driverId).toList();
    final validCount = driverDocs.where((d) => ['valid', 'permanent'].contains(d['status']?.toString().toLowerCase())).length;
    final expiringCount = driverDocs.where((d) => d['status']?.toString().toLowerCase() == 'expiring soon').length;
    final expiredCount = driverDocs.where((d) => d['status']?.toString().toLowerCase() == 'expired').length;
    final totalCount = driverDocs.length;

    final double validPct = totalCount > 0 ? (validCount / totalCount * 100) : 0.0;
    final double expiringPct = totalCount > 0 ? (expiringCount / totalCount * 100) : 0.0;
    final double expiredPct = totalCount > 0 ? (expiredCount / totalCount * 100) : 0.0;

    final String docType = doc['document_type'] ?? 'Driving License';
    final String docNo = doc['document_no'] ?? '—';
    final String issueDate = _formatDate(doc['issued_date']);
    final String expiryDate = _formatDate(doc['expiry_date']);
    final String authority = doc['issuing_authority'] ?? '—';
    final String status = doc['status'] ?? 'Valid';

    String daysLeftStr = '—';
    Color daysLeftColor = _textPrimary;
    if (status.toLowerCase() == 'permanent') {
      daysLeftStr = 'Permanent';
      daysLeftColor = _blue;
    } else if (doc['expiry_date'] != null) {
      try {
        final expiry = DateTime.parse(doc['expiry_date']);
        final diff = expiry.difference(DateTime.now()).inDays;
        if (diff < 0) {
          daysLeftStr = '${diff.abs()} Days Overdue';
          daysLeftColor = _red;
        } else {
          daysLeftStr = '$diff Days';
          daysLeftColor = diff <= 30 ? _red : (diff <= 90 ? _orange : _green);
        }
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent.withValues(alpha: 0.1),
                backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                child: drv['photo_url'] == null 
                  ? Text(drvName.substring(0, 1).toUpperCase(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _accent))
                  : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drvName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text(drvCode, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: _textSecondary),
                onPressed: () => setState(() => _selectedDocument = null),
                tooltip: 'Close details panel',
              ),
            ],
          ),
          const Divider(height: 24),

          // Document Summary (Donut Chart)
          Text('Document Summary', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 70,
                height: 70,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 1,
                    centerSpaceRadius: 20,
                    startDegreeOffset: 270,
                    sections: [
                      PieChartSectionData(color: _green, value: validCount.toDouble(), radius: 8, showTitle: false),
                      PieChartSectionData(color: _orange, value: expiringCount.toDouble(), radius: 8, showTitle: false),
                      PieChartSectionData(color: _red, value: expiredCount.toDouble(), radius: 8, showTitle: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  children: [
                    _buildDocSummaryLegendRow('Valid', '$validCount (${validPct.toStringAsFixed(0)}%)', _green),
                    const SizedBox(height: 4),
                    _buildDocSummaryLegendRow('Expiring Soon', '$expiringCount (${expiringPct.toStringAsFixed(0)}%)', _orange),
                    const SizedBox(height: 4),
                    _buildDocSummaryLegendRow('Expired', '$expiredCount (${expiredPct.toStringAsFixed(0)}%)', _red),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Document Details Table
          Text('Document Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          _buildDetailRow('Document Type', docType),
          _buildDetailRow('Document Number', docNo),
          _buildDetailRow('Issue Date', issueDate),
          _buildDetailRow('Expiry Date', doc['expiry_date'] != null ? expiryDate : '—'),
          _buildDetailRow('Issuing Authority', authority),
          _buildDetailRow('Status', status),
          _buildDetailRow('Days Left', daysLeftStr, valueColor: daysLeftColor),
          const SizedBox(height: 16),

          // Attachment block
          if (doc['file_name'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: _red, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc['file_name'], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary), overflow: TextOverflow.ellipsis),
                        Text(doc['file_size'] != null ? '${(doc['file_size'] / 1024).toStringAsFixed(0)} KB' : '245 KB', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, color: _accent, size: 18),
                    onPressed: () => _downloadDocumentFile(doc),
                    tooltip: 'Download Document PDF',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _directUploadDocument(doc),
                  icon: const Icon(Icons.upload_file_outlined, size: 14),
                  label: Text('Upload Document', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: const BorderSide(color: _accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAllDocumentsModal(filterDriverId: doc['driver_id']?.toString()),
                  icon: const Icon(Icons.list_alt_outlined, size: 14),
                  label: Text('View All Documents', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDocumentDetailsDialog(dynamic doc) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: _buildDocDetailsPanelSection(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocSummaryLegendRow(String title, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
        ),
        Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  // ─────── Tab 2: Performance view ───────
  Widget _buildPerformanceTab(double availableWidth) {
    // 1. Filtered Performance list
    final filteredPerf = _driverPerformance.where((perf) {
      if (_perfDriverFilter != 'All') {
        final name = perf['drivers']?['name'] ?? '';
        if (name != _perfDriverFilter) return false;
      }
      return true;
    }).toList();

    // 2. Aggregate statistics
    int totalCount = filteredPerf.length;
    double avgScore = 0.0;
    int excellent = 0;
    int good = 0;
    int needsImprovement = 0;
    int poor = 0;

    if (totalCount > 0) {
      double totalSum = 0.0;
      for (final r in filteredPerf) {
        final double score = (
          double.parse((r['attendance_score'] ?? 0.0).toString()) * 0.20 +
          double.parse((r['safety_score'] ?? 0.0).toString()) * 0.30 +
          double.parse((r['route_adherence_score'] ?? 0.0).toString()) * 0.20 +
          double.parse((r['vehicle_care_score'] ?? 0.0).toString()) * 0.15 +
          double.parse((r['feedback_score'] ?? 0.0).toString()) * 0.15
        );
        totalSum += score;
        if (score >= 4.5) {
          excellent++;
        } else if (score >= 3.5) good++;
        else if (score >= 2.5) needsImprovement++;
        else poor++;
      }
      avgScore = totalSum / totalCount;
    }

    final double excellentPct = totalCount > 0 ? (excellent.toDouble() / totalCount * 100) : 0.0;
    final double goodPct = totalCount > 0 ? (good.toDouble() / totalCount * 100) : 0.0;
    final double improvementPct = totalCount > 0 ? (needsImprovement.toDouble() / totalCount * 100) : 0.0;
    final double poorPct = totalCount > 0 ? (poor.toDouble() / totalCount * 100) : 0.0;

    // Find performance score of selected driver for details panel
    dynamic selectedPerf;
    if (_selectedDriver != null) {
      selectedPerf = _driverPerformance.firstWhere(
        (perf) => perf['driver_id'] == _selectedDriver['id'],
        orElse: () => null,
      );
    }

    final bool isDesktop = availableWidth > 1100;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards grid
          _buildKpiSection([
            _buildKpiCard('Average Performance Score', '${avgScore.toStringAsFixed(1)} / 5.0', 'Out of 5', const Color(0xFF8B5CF6), Icons.star),
            _buildKpiCard('Excellent Drivers', '$excellent', '${excellentPct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.verified_user_outlined, _green),
            _buildKpiCard('Good Drivers', '$good', '${goodPct.toStringAsFixed(2)}%', const Color(0xFF3B82F6), Icons.thumb_up_alt_outlined, _blue),
            _buildKpiCard('Needs Improvement', '$needsImprovement', '${improvementPct.toStringAsFixed(2)}%', const Color(0xFFF59E0B), Icons.warning_amber_rounded, _orange),
            _buildKpiCard('Poor Performance', '$poor', '${poorPct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.cancel_outlined, _red),
          ]),
          const SizedBox(height: 20),

          // Main content grid
          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: selectedPerf != null ? 65 : 100,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildScoreDistributionCard(excellent, good, needsImprovement, poor, totalCount)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTrendLineCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildFactorsProgressCard()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPerfFiltersSection(availableWidth),
                            _buildPerfTableSection(filteredPerf, availableWidth),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedPerf != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 35,
                    child: _buildPerfDetailsPanelSection(selectedPerf),
                  ),
                ],
              ],
            ),
          ] else ...[
            Column(
              children: [
                _buildScoreDistributionCard(excellent, good, needsImprovement, poor, totalCount),
                const SizedBox(height: 12),
                _buildTrendLineCard(),
                const SizedBox(height: 12),
                _buildFactorsProgressCard(),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPerfFiltersSection(availableWidth),
                      _buildPerfTableSection(filteredPerf, availableWidth),
                    ],
                  ),
                ),
              ],
            ),
            if (selectedPerf != null) ...[
              const SizedBox(height: 16),
              _buildPerfDetailsPanelSection(selectedPerf),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScoreDistributionCard(int exc, int gd, int avg, int pr, int total) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance Score Distribution', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 1,
                          centerSpaceRadius: 28,
                          startDegreeOffset: 270,
                          sections: [
                            PieChartSectionData(color: _green, value: exc.toDouble(), radius: 8, showTitle: false),
                            PieChartSectionData(color: _blue, value: gd.toDouble(), radius: 8, showTitle: false),
                            PieChartSectionData(color: _orange, value: avg.toDouble(), radius: 8, showTitle: false),
                            PieChartSectionData(color: _red, value: pr.toDouble(), radius: 8, showTitle: false),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$total', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: _textPrimary)),
                          Text('Drivers', style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDocSummaryLegendRow('Excellent (4.5 - 5.0)', '$exc', _green),
                      const SizedBox(height: 6),
                      _buildDocSummaryLegendRow('Good (3.5 - 4.4)', '$gd', _blue),
                      const SizedBox(height: 6),
                      _buildDocSummaryLegendRow('Average (2.5 - 3.4)', '$avg', _orange),
                      const SizedBox(height: 6),
                      _buildDocSummaryLegendRow('Poor (Below 2.5)', '$pr', _red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLineCard() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Performance Trend', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
                child: Text('Daily', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        if (val == 1) return Text('01 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        if (val == 7) return Text('07 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        if (val == 13) return Text('13 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        if (val == 19) return Text('19 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        if (val == 25) return Text('25 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        if (val == 31) return Text('31 May', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary));
                        return Container();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: 31,
                minY: 1,
                maxY: 5,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(1, 3.2),
                      FlSpot(5, 3.8),
                      FlSpot(10, 3.5),
                      FlSpot(15, 4.1),
                      FlSpot(20, 3.9),
                      FlSpot(25, 4.3),
                      FlSpot(31, 4.0),
                    ],
                    isCurved: true,
                    color: _accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _accent.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsProgressCard() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Performance Factors', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFactorRow('Timely Reporting', 4.6),
                _buildFactorRow('Safety Compliance', 4.5),
                _buildFactorRow('Route Adherence', 4.2),
                _buildFactorRow('Vehicle Care', 4.1),
                _buildFactorRow('Student Feedback', 4.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorRow(String factor, double score) {
    final double pct = score / 5.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(factor, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
            Text('$score', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: _border,
            color: _accent,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // --- Shared dropdown builder for premium uniform height ---
  Widget _buildPerfDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    IconData? prefixIcon,
  }) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      padding: EdgeInsets.only(left: prefixIcon != null ? 8 : 12, right: 4),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _textSecondary),
                style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfFiltersSection(double availableWidth) {
    final driverNames = _drivers.map((d) => (d['name'] ?? '').toString()).toSet().toList();
    driverNames.sort();

    // Shared button style constants
    const double kH = 36;
    final borderRadius = BorderRadius.circular(8);

    // 1. Driver Filter Dropdown
    final perfDriverFilterDropdown = _buildPerfDropdown(
      value: _perfDriverFilter,
      items: ['All', ...driverNames].map((drv) {
        return DropdownMenuItem<String>(
          value: drv,
          child: Text(drv == 'All' ? 'All Drivers' : drv, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) => setState(() => _perfDriverFilter = val!),
    );

    // 2. Vehicle Filter Dropdown
    final perfVehicleFilterDropdown = _buildPerfDropdown(
      value: _perfVehicleFilter,
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Vehicles', overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: 'Assigned', child: Text('Assigned Only', overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: 'Unassigned', child: Text('Unassigned Only', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (val) => setState(() => _perfVehicleFilter = val!),
    );

    // 3. Time Period Dropdown
    final perfTimePeriodDropdown = _buildPerfDropdown(
      value: _perfTimePeriod,
      prefixIcon: Icons.calendar_today_outlined,
      items: const [
        DropdownMenuItem(value: 'This Month', child: Text('This Month', overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: 'Last Month', child: Text('Last Month', overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (val) => setState(() => _perfTimePeriod = val!),
    );

    // 4. Reset Button
    final resetButton = SizedBox(
      height: kH,
      child: OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _perfDriverFilter = 'All';
            _perfVehicleFilter = 'All';
            _perfTimePeriod = 'This Month';
          });
        },
        icon: const Icon(Icons.filter_list_rounded, size: 15),
        label: Text('Reset', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _textSecondary,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          fixedSize: const Size.fromHeight(kH),
        ),
      ),
    );

    // 5. Refresh Button
    final refreshButton = SizedBox(
      width: kH,
      height: kH,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: borderRadius, side: const BorderSide(color: _border)),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: _loadData,
          child: const Center(child: Icon(Icons.refresh_rounded, size: 18, color: _textSecondary)),
        ),
      ),
    );

    // 6. Add Record Button
    final addButton = SizedBox(
      height: kH,
      child: ElevatedButton.icon(
        onPressed: () => _showPerformanceFormDialog(null),
        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
        label: Text('Add Record', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          fixedSize: const Size.fromHeight(kH),
        ),
      ),
    );

    // 7. Export Report Button
    final exportButton = SizedBox(
      height: kH,
      child: ElevatedButton.icon(
        onPressed: _exportPerformanceReport,
        icon: const Icon(Icons.download_outlined, size: 16, color: Colors.white),
        label: Text('Export Report', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          fixedSize: const Size.fromHeight(kH),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;

          if (w >= 860) {
            // Desktop: single row
            return Row(
              children: [
                SizedBox(width: 150, child: perfDriverFilterDropdown),
                const SizedBox(width: 8),
                SizedBox(width: 150, child: perfVehicleFilterDropdown),
                const SizedBox(width: 8),
                SizedBox(width: 155, child: perfTimePeriodDropdown),
                const SizedBox(width: 8),
                resetButton,
                const SizedBox(width: 6),
                refreshButton,
                const Spacer(),
                addButton,
                const SizedBox(width: 8),
                exportButton,
              ],
            );
          }

          // Narrower screens: wrap
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 145, child: perfDriverFilterDropdown),
              SizedBox(width: 145, child: perfVehicleFilterDropdown),
              SizedBox(width: 150, child: perfTimePeriodDropdown),
              resetButton,
              refreshButton,
              addButton,
              exportButton,
            ],
          );
        },
      ),
    );
  }

  // --- Column header helper for premium table ---
  DataColumn _perfCol(String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: _textSecondary, letterSpacing: 0.2),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildPerfTableSection(List<dynamic> records, double availableWidth) {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (records.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_outline_rounded, color: _textSecondary.withValues(alpha: 0.5), size: 40),
              const SizedBox(height: 12),
              Text('No performance records found', style: GoogleFonts.inter(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final totalCount = records.length;
    final startIndex = (_perfCurrentPage - 1) * _perfPageSize;
    final paginated = records.skip(startIndex).take(_perfPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: _border.withValues(alpha: 0.5)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: availableWidth > 1200 ? availableWidth : 1200),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 44,
              dividerThickness: 0.5,
              columnSpacing: 20,
              horizontalMargin: 16,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              columns: [
                _perfCol('Driver'),
                _perfCol('Vehicle'),
                _perfCol('Score'),
                _perfCol('Attend.'),
                _perfCol('Safety'),
                _perfCol('Route'),
                _perfCol('Care'),
                _perfCol('Feedback'),
                _perfCol('Trips'),
                _perfCol('Status'),
                _perfCol('Actions'),
              ],
              rows: paginated.map((perf) {
                final drv = perf['drivers'] ?? {};
                final drvName = drv['name'] ?? 'Driver';
                final drvCode = drv['driver_code'] ?? '';
                final isSelected = _selectedDriver != null && _selectedDriver['id'] == drv['id'];

                final veh = perf['bus_routes'] ?? perf['transport_routes'] ?? drv['bus_routes'] ?? drv['transport_routes'] ?? drv['vehicle'] ?? {};
                final String vehNo = veh['registration_no'] ?? veh['bus_number'] ?? '—';

                final double att = double.parse((perf['attendance_score'] ?? 5.0).toString());
                final double saf = double.parse((perf['safety_score'] ?? 5.0).toString());
                final double rt = double.parse((perf['route_adherence_score'] ?? 5.0).toString());
                final double vc = double.parse((perf['vehicle_care_score'] ?? 5.0).toString());
                final double fb = double.parse((perf['feedback_score'] ?? 5.0).toString());
                final int trips = int.parse((perf['trips_completed'] ?? 0).toString());

                // Average score
                final double score = (att * 0.20 + saf * 0.30 + rt * 0.20 + vc * 0.15 + fb * 0.15);

                String status = 'Good';
                Color statusColor = _blue;
                Color statusBg = _blue.withValues(alpha: 0.08);
                if (score >= 4.5) {
                  status = 'Excellent';
                  statusColor = _green;
                  statusBg = _green.withValues(alpha: 0.08);
                } else if (score >= 3.5) {
                  status = 'Good';
                  statusColor = _blue;
                  statusBg = _blue.withValues(alpha: 0.08);
                } else if (score >= 2.5) {
                  status = 'Average';
                  statusColor = _orange;
                  statusBg = _orange.withValues(alpha: 0.08);
                } else {
                  status = 'Poor';
                  statusColor = _red;
                  statusBg = _red.withValues(alpha: 0.08);
                }

                return DataRow(
                  selected: isSelected,
                  color: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return _accent.withValues(alpha: 0.04);
                    if (states.contains(WidgetState.hovered)) return const Color(0xFFF8FAFC);
                    return null;
                  }),
                  onSelectChanged: (val) {
                    setState(() {
                      _selectedDriver = drv;
                    });
                  },
                  cells: [
                    // Driver
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                            child: drv['photo_url'] == null 
                              ? Text(drvName.substring(0, 1).toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _accent))
                              : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(drvName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _textPrimary), overflow: TextOverflow.ellipsis),
                              Text(drvCode, style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Vehicle No.
                    DataCell(Text(vehNo, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary))),
                    // Total Score
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(score.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _textPrimary)),
                        ],
                      ),
                    ),
                    // Components
                    DataCell(Text(att.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary))),
                    DataCell(Text(saf.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary))),
                    DataCell(Text(rt.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary))),
                    DataCell(Text(vc.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary))),
                    DataCell(Text(fb.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, color: _textPrimary))),
                    // Trips Completed
                    DataCell(Text('$trips', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary))),
                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                        child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _miniActionBtn(Icons.visibility_outlined, _textSecondary, 'View', () => setState(() => _selectedDriver = drv)),
                          const SizedBox(width: 2),
                          _miniActionBtn(Icons.edit_outlined, _accent, 'Edit', () => _showPerformanceFormDialog(perf)),
                          const SizedBox(width: 2),
                          _miniActionBtn(Icons.delete_outline, _red, 'Delete', () => _deletePerformance(perf)),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),

        // Pagination row
        _buildPaginationRow(
          totalCount,
          startIndex,
          paginated.length,
          _perfPageSize,
          _perfCurrentPage,
          (newPage) => setState(() => _perfCurrentPage = newPage),
          (newSize) => setState(() {
            _perfPageSize = newSize;
            _perfCurrentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _miniActionBtn(IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 14,
        constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
      ),
    );
  }

  Widget _buildPerfDetailsPanelSection(dynamic perf) {
    final drv = perf['drivers'] ?? {};
    final drvName = drv['name'] ?? 'Driver';
    final drvCode = drv['driver_code'] ?? '';

    final double att = double.parse((perf['attendance_score'] ?? 5.0).toString());
    final double saf = double.parse((perf['safety_score'] ?? 5.0).toString());
    final double rt = double.parse((perf['route_adherence_score'] ?? 5.0).toString());
    final double vc = double.parse((perf['vehicle_care_score'] ?? 5.0).toString());
    final double fb = double.parse((perf['feedback_score'] ?? 5.0).toString());
    final int trips = int.parse((perf['trips_completed'] ?? 0).toString());

    final double score = (att * 0.20 + saf * 0.30 + rt * 0.20 + vc * 0.15 + fb * 0.15);

    // Calculate rank
    final sortedPerf = List.from(_driverPerformance);
    sortedPerf.sort((a, b) {
      final double sa = double.parse((a['attendance_score'] ?? 0).toString()) * 0.2 + double.parse((a['safety_score'] ?? 0).toString()) * 0.3 + double.parse((a['route_adherence_score'] ?? 0).toString()) * 0.2 + double.parse((a['vehicle_care_score'] ?? 0).toString()) * 0.15 + double.parse((a['feedback_score'] ?? 0).toString()) * 0.15;
      final double sb = double.parse((b['attendance_score'] ?? 0).toString()) * 0.2 + double.parse((b['safety_score'] ?? 0).toString()) * 0.3 + double.parse((b['route_adherence_score'] ?? 0).toString()) * 0.2 + double.parse((b['vehicle_care_score'] ?? 0).toString()) * 0.15 + double.parse((b['feedback_score'] ?? 0).toString()) * 0.15;
      return sb.compareTo(sa);
    });
    final int rank = sortedPerf.indexWhere((p) => p['id'] == perf['id']) + 1;
    final double percentile = (1.0 - (rank.toDouble() / sortedPerf.length)) * 100;
    final String percentileStr = percentile >= 95 ? 'Top 5%' : 'Top ${(100 - percentile).toStringAsFixed(0)}%';

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _accent.withValues(alpha: 0.1),
                backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                child: drv['photo_url'] == null 
                  ? Text(drvName.substring(0, 1).toUpperCase(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _accent))
                  : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drvName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
                    Text(drvCode, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: _textSecondary),
                onPressed: () => setState(() => _selectedDriver = null),
                tooltip: 'Close details panel',
              ),
            ],
          ),
          const Divider(height: 24),

          // Performance Score Indicator
          Text('Performance Summary', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 75,
                height: 75,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 5.0,
                      strokeWidth: 6,
                      backgroundColor: _border,
                      color: _green,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(score.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
                        Text('Out of 5', style: GoogleFonts.inter(fontSize: 8, color: _textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Details
              Expanded(
                child: Column(
                  children: [
                    _buildPerformanceMetricRow('Rank', '$rank of ${sortedPerf.length}', Icons.emoji_events_outlined),
                    const SizedBox(height: 4),
                    _buildPerformanceMetricRow('Percentile', percentileStr, Icons.trending_up),
                    const SizedBox(height: 4),
                    _buildPerformanceMetricRow('Trips Completed', '$trips', Icons.directions_bus_outlined),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Score breakdown
          Text('Score Breakdown', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          _buildScoreBreakdownProgressBar('Attendance (20%)', att),
          const SizedBox(height: 10),
          _buildScoreBreakdownProgressBar('Safety (30%)', saf),
          const SizedBox(height: 10),
          _buildScoreBreakdownProgressBar('Route Adherence (20%)', rt),
          const SizedBox(height: 10),
          _buildScoreBreakdownProgressBar('Vehicle Care (15%)', vc),
          const SizedBox(height: 10),
          _buildScoreBreakdownProgressBar('Feedback (15%)', fb),
          const Divider(height: 24),

          // Recent Feedback
          if (perf['recent_feedback'] != null) ...[
            Text('Recent Feedback', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${perf['recent_feedback']}"',
                    style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: _textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('— Parent', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _textSecondary)),
                      Text(_formatDate(perf['recent_feedback_date']?.toString()), style: GoogleFonts.inter(fontSize: 9, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {},
              child: Text('View all feedback', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
            ),
            const SizedBox(height: 16),
          ],

          // View Full Profile button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('View Full Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
        ),
        Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildScoreBreakdownProgressBar(String label, double val) {
    // ─────── Tab 3: Training view ───────
    final double pct = val / 5.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 12),
                const SizedBox(width: 4),
                Text('$val', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: _border,
            color: _green,
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  // ─────── Tab 3: Training view ───────
  Widget _buildTrainingTab(double availableWidth) {
    final filtered = _filteredTrainings;
    final totalCount = filtered.length;
    final startIndex = (_trainCurrentPage - 1) * _trainPageSize;
    final paginated = filtered.skip(startIndex).take(_trainPageSize).toList();

    // Stats
    final totalTrain = _driverTrainings.length;
    final completedTrain = _driverTrainings.where((t) => t['status'] == 'Completed').length;
    final inProgressTrain = _driverTrainings.where((t) => t['status'] == 'In Progress').length;
    final upcomingTrain = _driverTrainings.where((t) => t['status'] == 'Upcoming').length;
    final overdueTrain = _driverTrainings.where((t) => t['status'] == 'Overdue').length;

    final double completedPct = totalTrain > 0 ? (completedTrain / totalTrain * 100) : 0.0;
    final double progressPct = totalTrain > 0 ? (inProgressTrain / totalTrain * 100) : 0.0;
    final double upcomingPct = totalTrain > 0 ? (upcomingTrain / totalTrain * 100) : 0.0;
    final double overduePct = totalTrain > 0 ? (overdueTrain / totalTrain * 100) : 0.0;

    final bool isDesktop = availableWidth > 1100;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection([
            _buildKpiCard('Total Programs', '$totalTrain', 'All time', const Color(0xFF8B5CF6), Icons.school_outlined),
            _buildKpiCard('Completed', '$completedTrain', '${completedPct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.check_circle_outline, _green),
            _buildKpiCard('In Progress', '$inProgressTrain', '${progressPct.toStringAsFixed(2)}%', const Color(0xFFF59E0B), Icons.pending_outlined, _orange),
            _buildKpiCard('Upcoming Programs', '$upcomingTrain', '${upcomingPct.toStringAsFixed(2)}%', const Color(0xFF3B82F6), Icons.next_plan_outlined, _blue),
            _buildKpiCard('Overdue / Warning', '$overdueTrain', '${overduePct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.warning_amber_rounded, _red),
          ]),
          const SizedBox(height: 20),

          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _selectedTraining != null ? 65 : 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTrainFiltersSection(availableWidth),
                        _buildTrainTableSection(paginated, totalCount, startIndex, availableWidth),
                      ],
                    ),
                  ),
                ),
                if (_selectedTraining != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 35,
                    child: _buildTrainDetailsPanelSection(_selectedTraining),
                  ),
                ],
              ],
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrainFiltersSection(availableWidth),
                  _buildTrainTableSection(paginated, totalCount, startIndex, availableWidth),
                ],
              ),
            ),
            if (_selectedTraining != null) ...[
              const SizedBox(height: 16),
              _buildTrainDetailsPanelSection(_selectedTraining),
            ],
          ],
          const SizedBox(height: 30),
          Text('Upcoming Training Programs', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: _textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildUpcomingProgramCard(
                  'Defensive Driving Techniques',
                  'Safety',
                  'Road Safety Academy',
                  '25 May 2024',
                  '09:00 AM - 05:00 PM',
                  12,
                ),
                const SizedBox(width: 12),
                _buildUpcomingProgramCard(
                  'Advanced First Aid',
                  'Medical',
                  'Red Cross Society',
                  '05 Jun 2024',
                  '10:00 AM - 04:00 PM',
                  8,
                ),
                const SizedBox(width: 12),
                _buildUpcomingProgramCard(
                  'Eco-Driving Seminar',
                  'Awareness',
                  'Green Earth Foundation',
                  '12 Jun 2024',
                  '11:00 AM - 01:00 PM',
                  15,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUpcomingProgramCard(
    String program,
    String type,
    String provider,
    String date,
    String timeSlot,
    int registeredCount,
  ) {
    Color typeColor = const Color(0xFF4F46E5);
    Color typeBg = const Color(0xFFEEF2FF);
    if (type.toLowerCase() == 'medical') {
      typeColor = const Color(0xFF0284C7);
      typeBg = const Color(0xFFF0F9FF);
    } else if (type.toLowerCase() == 'awareness') {
      typeColor = const Color(0xFF0F766E);
      typeBg = const Color(0xFFF0FDFA);
    }

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(type, style: GoogleFonts.inter(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 14, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text('$registeredCount Registered', style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(program, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
          const SizedBox(height: 4),
          Text(provider, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
          const Spacer(),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(date, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.access_time_outlined, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(timeSlot, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrainFiltersSection(double availableWidth) {
    final searchField = _uSearch(controller: _trainSearchController, hint: 'Search driver, program...');
    final statusFilter = _uDropdown(
      value: _trainStatusFilter,
      items: ['All', 'Completed', 'In Progress', 'Upcoming', 'Overdue'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _trainStatusFilter = val!; _trainCurrentPage = 1; }),
    );
    final typeFilter = _uDropdown(
      value: _trainTypeFilter,
      items: ['All', 'Safety', 'Medical', 'Technical', 'Operational'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Types' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _trainTypeFilter = val!; _trainCurrentPage = 1; }),
    );
    final resetButton = _uResetBtn(() {
      setState(() { _trainSearchController.clear(); _trainSearchQuery = ''; _trainStatusFilter = 'All'; _trainTypeFilter = 'All'; _trainCurrentPage = 1; });
    });
    final refreshButton = _uRefreshBtn(_loadData, 'Refresh Training');
    final addBtn = _uBtn(label: 'Add Record', icon: Icons.add_rounded, onPressed: () => _showTrainingFormDialog(null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w >= 860) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: statusFilter),
                const SizedBox(width: 8),
                SizedBox(width: 135, child: typeFilter),
                const SizedBox(width: 8),
                resetButton,
                const SizedBox(width: 6),
                refreshButton,
                const Spacer(),
                addBtn,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [SizedBox(width: 140, child: statusFilter), SizedBox(width: 135, child: typeFilter), resetButton, refreshButton, addBtn],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrainTableSection(List<dynamic> paginated, int totalCount, int startIndex, double availableWidth) {
    if (paginated.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, color: _textSecondary, size: 36),
              const SizedBox(height: 12),
              Text('No training records found', style: GoogleFonts.inter(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: math.max(availableWidth, 1000)),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columnSpacing: 18,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columns: [
                _dataCol('Driver'),
                _dataCol('Program'),
                _dataCol('Type'),
                _dataCol('Provider'),
                _dataCol('Start'),
                _dataCol('End'),
                _dataCol('Status'),
                _dataCol('Cert.'),
                _dataCol('Next Due'),
                _dataCol('Actions'),
              ],
              rows: paginated.map((train) {
                final isSelected = _selectedTraining != null && _selectedTraining['id'] == train['id'];
                final drv = train['drivers'] ?? {};
                final status = train['status'] ?? 'Completed';
                final hasCert = train['certificate_url'] != null && train['certificate_url'].toString().isNotEmpty;

                Color statusColor;
                Color statusBg;
                switch (status.toLowerCase()) {
                  case 'completed':
                    statusColor = _green;
                    statusBg = _green.withValues(alpha: 0.12);
                    break;
                  case 'in progress':
                    statusColor = _orange;
                    statusBg = _orange.withValues(alpha: 0.12);
                    break;
                  case 'upcoming':
                    statusColor = _blue;
                    statusBg = _blue.withValues(alpha: 0.12);
                    break;
                  case 'overdue':
                    statusColor = _red;
                    statusBg = _red.withValues(alpha: 0.12);
                    break;
                  default:
                    statusColor = _gray;
                    statusBg = _gray.withValues(alpha: 0.12);
                }

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      _selectedTraining = train;
                    });
                  },
                  cells: [
                    // Driver
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                            child: drv['photo_url'] == null
                                ? Text(drv['name']?.substring(0, 1).toUpperCase() ?? 'D', style: GoogleFonts.inter(color: _accent, fontSize: 11, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(drv['name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12)),
                              Text(drv['driver_code'] ?? '—', style: GoogleFonts.inter(color: _textSecondary, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(train['training_program'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(Text(train['training_type'] ?? '—')),
                    DataCell(Text(train['provider'] ?? '—')),
                    DataCell(Text(_formatDate(train['start_date']))),
                    DataCell(Text(_formatDate(train['end_date']))),
                    // Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Certificate PDF button
                    DataCell(
                      hasCert
                          ? IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: _red, size: 18),
                              tooltip: 'View Certificate',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Opening certificate: ${train['certificate_url']}'), backgroundColor: _blue),
                                );
                              },
                            )
                          : const Text('—', style: TextStyle(color: _textSecondary)),
                    ),
                    DataCell(Text(_formatDate(train['next_due_date']))),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: 'Edit',
                            onPressed: () => _showTrainingFormDialog(train),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                            tooltip: 'Delete',
                            onPressed: () => _deleteTraining(train),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        _buildPaginationRow(
          totalCount,
          startIndex,
          paginated.length,
          _trainPageSize,
          _trainCurrentPage,
          (newPage) => setState(() => _trainCurrentPage = newPage),
          (newSize) => setState(() {
            _trainPageSize = newSize;
            _trainCurrentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildTrainDetailsPanelSection(dynamic train) {
    if (train == null) return Container();
    final drv = train['drivers'] ?? {};
    final String status = train['status'] ?? 'Completed';
    final startTime = train['start_time'] ?? '09:00 AM';
    final endTime = train['end_time'] ?? '05:00 PM';
    
    Color statusColor;
    Color statusBg;
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = _green;
        statusBg = _green.withValues(alpha: 0.12);
        break;
      case 'in progress':
        statusColor = _orange;
        statusBg = _orange.withValues(alpha: 0.12);
        break;
      case 'upcoming':
        statusColor = _blue;
        statusBg = _blue.withValues(alpha: 0.12);
        break;
      case 'overdue':
        statusColor = _red;
        statusBg = _red.withValues(alpha: 0.12);
        break;
      default:
        statusColor = _gray;
        statusBg = _gray.withValues(alpha: 0.12);
    }

    // Mandatory Compliance logic
    final String driverId = train['driver_id'] ?? '';
    final driverTrainings = _driverTrainings.where((t) => t['driver_id'] == driverId).toList();
    
    final bool hasDefensive = driverTrainings.any((t) => t['training_program'].toString().toLowerCase().contains('defensive') && t['status'].toString().toLowerCase() == 'completed');
    final bool hasFirstAid = driverTrainings.any((t) => t['training_program'].toString().toLowerCase().contains('first aid') && t['status'].toString().toLowerCase() == 'completed');
    final bool hasPassenger = driverTrainings.any((t) => t['training_program'].toString().toLowerCase().contains('passenger') && t['status'].toString().toLowerCase() == 'completed');
    final bool hasFireSafety = driverTrainings.any((t) => (t['training_program'].toString().toLowerCase().contains('fire') || t['training_program'].toString().toLowerCase().contains('maintenance')) && t['status'].toString().toLowerCase() == 'completed');

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Driver Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Driver details block
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accent.withValues(alpha: 0.1),
                backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                child: drv['photo_url'] == null
                    ? Text(drv['name']?.substring(0, 1).toUpperCase() ?? 'D', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drv['name'] ?? 'Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(drv['driver_code'] ?? '—', style: GoogleFonts.inter(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Phone & Email & joined date
          _buildDetailRow('Phone', drv['phone'] ?? '—'),
          _buildDetailRow('Email', drv['email'] ?? '—'),
          _buildDetailRow('Joined Date', _formatDate(drv['joined_date'])),
          _buildDetailRow('License Expiry', _formatDate(drv['license_expiry_date'])),

          const Divider(height: 24),
          _buildTrainingStatusDonutChart(train),

          const Divider(height: 24),
          Text('Mandatory Compliance', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          _buildComplianceCheckbox('Defensive Driving Techniques', hasDefensive),
          _buildComplianceCheckbox('First Aid Training', hasFirstAid),
          _buildComplianceCheckbox('Passenger Safety Awareness', hasPassenger),
          _buildComplianceCheckbox('Fire Safety & Emergency / Technical', hasFireSafety),

          const Divider(height: 24),
          Text('Training Program Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          _buildDetailRow('Program Title', train['training_program'] ?? '—'),
          _buildDetailRow('Training Type', train['training_type'] ?? '—'),
          _buildDetailRow('Provider', train['provider'] ?? '—'),
          _buildDetailRow('Duration / Timing', '$startTime - $endTime'),
          _buildDetailRow('Start Date', _formatDate(train['start_date'])),
          _buildDetailRow('End Date', _formatDate(train['end_date'])),
          _buildDetailRow('Recertification Due', _formatDate(train['next_due_date'])),
          
          if (train['certificate_url'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bg, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: _red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Certificate.pdf', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
                        Text('PDF Document', style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.download, color: _accent, size: 20),
                ],
              ),
            ),
          ],
          
          const Divider(height: 24),
          Text('Quick Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showTrainingFormDialog(train),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Record', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteTraining(train),
                  icon: const Icon(Icons.delete_outline, size: 14, color: _red),
                  label: const Text('Delete Record', style: TextStyle(color: _red, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCheckbox(String title, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
            color: checked ? _green : _textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12, 
                color: checked ? _textPrimary : _textSecondary,
                fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingStatusDonutChart(dynamic train) {
    final driverId = train['driver_id'];
    final driverTrainings = _driverTrainings.where((t) => t['driver_id'] == driverId).toList();
    final total = driverTrainings.length;
    if (total == 0) return const SizedBox();

    final completed = driverTrainings.where((t) => t['status']?.toString().toLowerCase() == 'completed').length;
    final inProgress = driverTrainings.where((t) => t['status']?.toString().toLowerCase() == 'in progress').length;
    final upcoming = driverTrainings.where((t) => t['status']?.toString().toLowerCase() == 'upcoming').length;
    final overdue = driverTrainings.where((t) => t['status']?.toString().toLowerCase() == 'overdue').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Training Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 26,
                  sections: [
                    if (completed > 0) PieChartSectionData(color: _green, value: completed.toDouble(), radius: 8, showTitle: false),
                    if (inProgress > 0) PieChartSectionData(color: _orange, value: inProgress.toDouble(), radius: 8, showTitle: false),
                    if (upcoming > 0) PieChartSectionData(color: _blue, value: upcoming.toDouble(), radius: 8, showTitle: false),
                    if (overdue > 0) PieChartSectionData(color: _red, value: overdue.toDouble(), radius: 8, showTitle: false),
                    if (completed == 0 && inProgress == 0 && upcoming == 0 && overdue == 0)
                      PieChartSectionData(color: _gray, value: 1.0, radius: 8, showTitle: false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChartLegendItem('Completed', '$completed', _green),
                  const SizedBox(height: 4),
                  _buildChartLegendItem('In Progress', '$inProgress', _orange),
                  const SizedBox(height: 4),
                  _buildChartLegendItem('Upcoming', '$upcoming', _blue),
                  const SizedBox(height: 4),
                  _buildChartLegendItem('Overdue', '$overdue', _red),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartLegendItem(String title, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
        ),
        Text(count, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Future<void> _showTrainingFormDialog(dynamic existing) async {
    await _ensureLookupsLoaded();
    if (!mounted) return;

    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final Map<String, dynamic> uniqueDrivers = {};
    for (final d in _drivers) {
      final id = d['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueDrivers[id] = d;
    }

    String? selectedDriverId = existing?['driver_id']?.toString();
    if (selectedDriverId != null && !uniqueDrivers.containsKey(selectedDriverId)) {
      selectedDriverId = null;
    }

    final programController = TextEditingController(text: existing?['training_program']);
    String type = existing?['training_type'] ?? 'Safety';
    final providerController = TextEditingController(text: existing?['provider'] ?? 'Road Safety Academy');
    final startController = TextEditingController(text: existing?['start_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final endController = TextEditingController(text: existing?['end_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 5))));
    final certController = TextEditingController(text: existing?['certificate_url']);
    final dueController = TextEditingController(text: existing?['next_due_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 365))));
    String status = existing?['status'] ?? 'In Progress';
    
    // New fields
    final startTimeController = TextEditingController(text: existing?['start_time'] ?? '09:00 AM');
    final endTimeController = TextEditingController(text: existing?['end_time'] ?? '05:00 PM');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Training Record' : 'Add Training Record', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    clipBehavior: Clip.none,
                    shrinkWrap: true,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedDriverId,
                        decoration: const InputDecoration(labelText: 'Driver *', border: OutlineInputBorder()),
                        items: uniqueDrivers.values.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['name'] ?? 'Driver'} (${d['driver_code'] ?? 'DRV'})'))).toList(),
                        validator: (val) => val == null ? 'Required' : null,
                        onChanged: isEdit ? null : (val) => setDialogState(() => selectedDriverId = val),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: programController,
                        decoration: const InputDecoration(labelText: 'Program Title *', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: type,
                              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                              items: ['Safety', 'Medical', 'Technical', 'Operational', 'Awareness'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => type = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: ['Completed', 'In Progress', 'Upcoming', 'Overdue'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => status = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: providerController,
                        decoration: const InputDecoration(labelText: 'Training Provider *', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startController,
                              decoration: InputDecoration(
                                labelText: 'Start Date *', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, startController)),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: endController,
                              decoration: InputDecoration(
                                labelText: 'End Date', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, endController)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startTimeController,
                              decoration: const InputDecoration(labelText: 'Start Time *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: endTimeController,
                              decoration: const InputDecoration(labelText: 'End Time *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dueController,
                        decoration: InputDecoration(
                          labelText: 'Recertification Due Date', 
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, dueController)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: certController,
                        decoration: const InputDecoration(labelText: 'Certificate URL', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        "school_id": widget.schoolId ?? '11111111-1111-1111-1111-111111111111',
                        "driver_id": selectedDriverId,
                        "training_program": programController.text,
                        "training_type": type,
                        "provider": providerController.text,
                        "start_date": startController.text,
                        "end_date": endController.text.isNotEmpty ? endController.text : null,
                        "next_due_date": dueController.text.isNotEmpty ? dueController.text : null,
                        "certificate_url": certController.text.isNotEmpty ? certController.text : null,
                        "status": status,
                        "start_time": startTimeController.text,
                        "end_time": endTimeController.text,
                      };

                      try {
                        if (isEdit) {
                          await ApiService().put('/transport/drivers/training/${existing['id']}', data);
                        } else {
                          await ApiService().post('/transport/drivers/training', data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Training record updated' : 'Training record logged successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save training: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save' : 'Log Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteTraining(dynamic train) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove Training Record', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to remove/delete this training record? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/drivers/training/${train['id']}');
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedTraining = null;
                  });
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Training record removed'), backgroundColor: _green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete training record: $e'), backgroundColor: _red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ─────── Tab 5: Violations view ───────
  Widget _buildViolationsTab(double availableWidth) {
    final filtered = _filteredViolations;
    final totalCount = filtered.length;
    final startIndex = (_violCurrentPage - 1) * _violPageSize;
    final paginated = filtered.skip(startIndex).take(_violPageSize).toList();

    // Stats
    final totalViol = _driverViolations.length;
    final pendingViol = _driverViolations.where((v) => v['status'] == 'Pending').length;
    final resolvedViol = _driverViolations.where((v) => v['status'] == 'Resolved').length;
    
    double totalFineAmount = 0.0;
    double paidFineAmount = 0.0;
    for (final v in _driverViolations) {
      final amt = double.parse((v['fine_amount'] ?? 0.0).toString());
      totalFineAmount += amt;
      if (v['status'] == 'Resolved') {
        paidFineAmount += amt;
      }
    }

    final double pendingPct = totalViol > 0 ? (pendingViol / totalViol * 100) : 0.0;
    final double resolvedPct = totalViol > 0 ? (resolvedViol / totalViol * 100) : 0.0;
    final double paidPct = totalFineAmount > 0 ? (paidFineAmount / totalFineAmount * 100) : 0.0;

    final bool isDesktop = availableWidth > 1100;
    int kpiColumns = isDesktop ? 5 : (availableWidth > 750 ? 3 : 1);
    final kpiCardWidth = (availableWidth - 32 - (kpiColumns - 1) * 12) / kpiColumns;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKpiSection([
            _buildKpiCard('Total Violations', '$totalViol', 'All time', const Color(0xFF8B5CF6), Icons.warning_amber_rounded),
            _buildKpiCard('Pending Violations', '$pendingViol', '${pendingPct.toStringAsFixed(2)}%', const Color(0xFFEF4444), Icons.hourglass_empty_rounded, _red),
            _buildKpiCard('Resolved Violations', '$resolvedViol', '${resolvedPct.toStringAsFixed(2)}%', const Color(0xFF10B981), Icons.check_circle_outline, _green),
            _buildKpiCard('Total Fines', '\u{20B9} ${totalFineAmount.toStringAsFixed(0)}', 'Charged', const Color(0xFFF59E0B), Icons.monetization_on_outlined, _orange),
            _buildKpiCard('Fines Paid', '\u{20B9} ${paidFineAmount.toStringAsFixed(0)}', '${paidPct.toStringAsFixed(2)}% paid', const Color(0xFF3B82F6), Icons.payment_outlined, _blue),
          ]),
          const SizedBox(height: 20),

          if (isDesktop) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: _selectedViolation != null ? 65 : 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildViolFiltersSection(availableWidth),
                        _buildViolTableSection(paginated, totalCount, startIndex, availableWidth),
                      ],
                    ),
                  ),
                ),
                if (_selectedViolation != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 35,
                    child: _buildViolDetailsPanelSection(_selectedViolation),
                  ),
                ],
              ],
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildViolFiltersSection(availableWidth),
                  _buildViolTableSection(paginated, totalCount, startIndex, availableWidth),
                ],
              ),
            ),
            if (_selectedViolation != null) ...[
              const SizedBox(height: 16),
              _buildViolDetailsPanelSection(_selectedViolation),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildViolFiltersSection(double availableWidth) {
    final searchField = _uSearch(controller: _violSearchController, hint: 'Search driver, violation...');
    final statusFilter = _uDropdown(
      value: _violStatusFilter,
      items: ['All', 'Pending', 'Resolved', 'Cancelled', 'Waived'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _violStatusFilter = val!; _violCurrentPage = 1; }),
    );
    final severityFilter = _uDropdown(
      value: _violSeverityFilter,
      items: ['All', 'High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Severity' : s, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (val) => setState(() { _violSeverityFilter = val!; _violCurrentPage = 1; }),
    );
    final resetButton = _uResetBtn(() {
      setState(() { _violSearchController.clear(); _violSearchQuery = ''; _violStatusFilter = 'All'; _violSeverityFilter = 'All'; _violCurrentPage = 1; });
    });
    final refreshButton = _uRefreshBtn(_loadData, 'Refresh Violations');
    final addBtn = _uBtn(label: 'Log Violation', icon: Icons.add_rounded, onPressed: () => _showViolationFormDialog(null));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          if (w >= 860) {
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                SizedBox(width: 130, child: statusFilter),
                const SizedBox(width: 8),
                SizedBox(width: 130, child: severityFilter),
                const SizedBox(width: 8),
                resetButton,
                const SizedBox(width: 6),
                refreshButton,
                const Spacer(),
                addBtn,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [SizedBox(width: 130, child: statusFilter), SizedBox(width: 130, child: severityFilter), resetButton, refreshButton, addBtn],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViolTableSection(List<dynamic> paginated, int totalCount, int startIndex, double availableWidth) {
    if (paginated.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: _textSecondary, size: 36),
              const SizedBox(height: 12),
              Text('No violations found', style: GoogleFonts.inter(color: _textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: math.max(availableWidth, 1000)),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columnSpacing: 20,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 56,
              columns: [
                _dataCol('Driver'),
                _dataCol('Violation'),
                _dataCol('Date'),
                _dataCol('Location'),
                _dataCol('Vehicle'),
                _dataCol('Severity'),
                _dataCol('Status'),
                _dataCol('Fine'),
                _dataCol('Actions'),
              ],
              rows: paginated.map((viol) {
                final isSelected = _selectedViolation != null && _selectedViolation['id'] == viol['id'];
                final drv = viol['drivers'] ?? {};
                final veh = viol['bus_routes'] ?? viol['transport_routes'] ?? drv['bus_routes'] ?? drv['transport_routes'] ?? drv['vehicle'] ?? {};
                final vehicleText = veh['registration_no'] ?? veh['bus_number'] ?? '—';
                final vehicleType = veh['vehicle_type'] ?? 'Bus';
                final status = viol['status'] ?? 'Pending';
                final severity = viol['severity'] ?? 'Medium';
                final double fine = double.parse((viol['fine_amount'] ?? 0.0).toString());

                Color statusColor;
                Color statusBg;
                switch (status.toLowerCase()) {
                  case 'resolved':
                    statusColor = _green;
                    statusBg = _green.withValues(alpha: 0.12);
                    break;
                  case 'pending':
                    statusColor = _red;
                    statusBg = _red.withValues(alpha: 0.12);
                    break;
                  case 'cancelled':
                    statusColor = _gray;
                    statusBg = _gray.withValues(alpha: 0.12);
                    break;
                  case 'waived':
                    statusColor = _blue;
                    statusBg = _blue.withValues(alpha: 0.12);
                    break;
                  default:
                    statusColor = _orange;
                    statusBg = _orange.withValues(alpha: 0.12);
                }

                Color sevColor;
                Color sevBg;
                switch (severity.toLowerCase()) {
                  case 'high':
                    sevColor = _red;
                    sevBg = _red.withValues(alpha: 0.12);
                    break;
                  case 'medium':
                    sevColor = _orange;
                    sevBg = _orange.withValues(alpha: 0.12);
                    break;
                  default:
                    sevColor = _blue;
                    sevBg = _blue.withValues(alpha: 0.12);
                }

                // Format DateTime
                String formattedDt = '—';
                if (viol['date_time'] != null) {
                  try {
                    formattedDt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(viol['date_time']));
                  } catch (_) {
                    formattedDt = viol['date_time'];
                  }
                }

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      _selectedViolation = viol;
                    });
                  },
                  cells: [
                    // Driver
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _accent.withValues(alpha: 0.1),
                            backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                            child: drv['photo_url'] == null
                                ? Text(drv['name']?.substring(0, 1).toUpperCase() ?? 'D', style: GoogleFonts.inter(color: _accent, fontSize: 11, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(drv['name'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(drv['driver_code'] ?? '—', style: GoogleFonts.inter(color: _textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Violation Type (Type + Description details below it)
                    DataCell(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(viol['violation_type'] ?? '—', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(viol['description'] ?? '—', style: GoogleFonts.inter(color: _textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    DataCell(Text(formattedDt, style: GoogleFonts.inter(fontSize: 12))),
                    DataCell(Text(viol['location'] ?? '—', style: GoogleFonts.inter(fontSize: 12))),
                    // Vehicle (number + type below it)
                    DataCell(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(vehicleText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(vehicleType, style: GoogleFonts.inter(color: _textSecondary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Severity badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: sevBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(severity, style: GoogleFonts.inter(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    // Status chip
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                        child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    // Fine Amount
                    DataCell(Text('\u{20B9} ${fine.toStringAsFixed(0)}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12))),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: 'Edit',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => _showViolationFormDialog(viol),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: _red),
                            tooltip: 'Delete',
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () => _deleteViolation(viol),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        _buildPaginationRow(
          totalCount,
          startIndex,
          paginated.length,
          _violPageSize,
          _violCurrentPage,
          (newPage) => setState(() => _violCurrentPage = newPage),
          (newSize) => setState(() {
            _violPageSize = newSize;
            _violCurrentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildViolDetailsPanelSection(dynamic viol) {
    if (viol == null) return Container();
    final drv = viol['drivers'] ?? {};
    final veh = viol['bus_routes'] ?? viol['transport_routes'] ?? drv['bus_routes'] ?? drv['transport_routes'] ?? drv['vehicle'] ?? {};
    final String status = viol['status'] ?? 'Pending';
    final String severity = viol['severity'] ?? 'Medium';
    final double fine = double.parse((viol['fine_amount'] ?? 0.0).toString());
    
    Color statusColor;
    Color statusBg;
    switch (status.toLowerCase()) {
      case 'resolved':
        statusColor = _green;
        statusBg = _green.withValues(alpha: 0.12);
        break;
      case 'pending':
        statusColor = _red;
        statusBg = _red.withValues(alpha: 0.12);
        break;
      case 'cancelled':
        statusColor = _gray;
        statusBg = _gray.withValues(alpha: 0.12);
        break;
      case 'waived':
        statusColor = _blue;
        statusBg = _blue.withValues(alpha: 0.12);
        break;
      default:
        statusColor = _orange;
        statusBg = _orange.withValues(alpha: 0.12);
    }

    Color sevColor;
    switch (severity.toLowerCase()) {
      case 'high':
        sevColor = _red;
        break;
      case 'medium':
        sevColor = _orange;
        break;
      default:
        sevColor = _blue;
    }

    String formattedDt = '—';
    if (viol['date_time'] != null) {
      try {
        formattedDt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(viol['date_time']));
      } catch (_) {
        formattedDt = viol['date_time'];
      }
    }

    // Dynamic stats computations for top violation types
    final String driverId = viol['driver_id'] ?? '';
    final driverViolations = _driverViolations.where((v) => v['driver_id'] == driverId).toList();
    final totalViols = driverViolations.length;
    
    final speedCount = driverViolations.where((v) => v['violation_type'].toString().toLowerCase().contains('speed')).length;
    final signalCount = driverViolations.where((v) => v['violation_type'].toString().toLowerCase().contains('signal')).length;
    final beltCount = driverViolations.where((v) => v['violation_type'].toString().toLowerCase().contains('seat') || v['violation_type'].toString().toLowerCase().contains('belt')).length;
    final mobileCount = driverViolations.where((v) => v['violation_type'].toString().toLowerCase().contains('mobile')).length;
    final otherCount = totalViols - (speedCount + signalCount + beltCount + mobileCount);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Driver Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: _textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accent.withValues(alpha: 0.1),
                backgroundImage: drv['photo_url'] != null ? NetworkImage(drv['photo_url']) : null,
                child: drv['photo_url'] == null
                    ? Text(drv['name']?.substring(0, 1).toUpperCase() ?? 'D', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drv['name'] ?? 'Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(drv['driver_code'] ?? '—', style: GoogleFonts.inter(color: _textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Phone', drv['phone'] ?? '—'),
          _buildDetailRow('Email', drv['email'] ?? '—'),
          _buildDetailRow('Joined Date', _formatDate(drv['joined_date'])),

          const Divider(height: 24),
          _buildViolationStatusDonutChart(driverViolations),

          const Divider(height: 24),
          Text('Top Violation Types', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          _buildViolationOccurrenceRow('Overspeeding', speedCount, totalViols, _red),
          _buildViolationOccurrenceRow('Signal Jump', signalCount, totalViols, _orange),
          _buildViolationOccurrenceRow('Seat Belt Not Worn', beltCount, totalViols, _blue),
          _buildViolationOccurrenceRow('Mobile Usage', mobileCount, totalViols, _green),
          if (otherCount > 0)
            _buildViolationOccurrenceRow('Other Deviations', otherCount, totalViols, _gray),

          const Divider(height: 24),
          Text('Infraction Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          _buildDetailRow('Violation Type', viol['violation_type'] ?? '—'),
          _buildDetailRow('Severity Level', severity, valueColor: sevColor),
          _buildDetailRow('Timestamp', formattedDt),
          _buildDetailRow('Location', viol['location'] ?? '—'),
          _buildDetailRow('Vehicle Involved', '${veh['registration_no'] ?? veh['bus_number'] ?? '—'} (${veh['vehicle_type'] ?? '—'})'),
          _buildDetailRow('Fine Amount', '\u{20B9} ${fine.toStringAsFixed(2)}'),
          _buildDetailRow('Description', viol['description'] ?? '—'),
          
          const Divider(height: 24),
          Text('Quick Actions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showViolationFormDialog(viol),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Infraction', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteViolation(viol),
                  icon: const Icon(Icons.delete_outline, size: 14, color: _red),
                  label: const Text('Delete Record', style: TextStyle(color: _red, fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ApiService().put('/transport/drivers/violations/${viol['id']}', {"status": "Resolved"});
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Violation marked as Resolved / Paid'), backgroundColor: _green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to resolve violation: $e'), backgroundColor: _red),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Mark as Resolved (Fine Paid)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViolationOccurrenceRow(String title, int count, int total, Color color) {
    final double pct = total > 0 ? (count / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: _textPrimary)),
              Text('$count occurrences', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationStatusDonutChart(List<dynamic> driverViolations) {
    final total = driverViolations.length;
    if (total == 0) return const SizedBox();

    final pending = driverViolations.where((v) => v['status']?.toString().toLowerCase() == 'pending').length;
    final resolved = driverViolations.where((v) => v['status']?.toString().toLowerCase() == 'resolved').length;
    final other = total - (pending + resolved);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Violation Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: _textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 26,
                  sections: [
                    if (pending > 0) PieChartSectionData(color: _red, value: pending.toDouble(), radius: 8, showTitle: false),
                    if (resolved > 0) PieChartSectionData(color: _green, value: resolved.toDouble(), radius: 8, showTitle: false),
                    if (other > 0) PieChartSectionData(color: _gray, value: other.toDouble(), radius: 8, showTitle: false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChartLegendItem('Pending', '$pending', _red),
                  const SizedBox(height: 4),
                  _buildChartLegendItem('Resolved / Paid', '$resolved', _green),
                  if (other > 0) ...[
                    const SizedBox(height: 4),
                    _buildChartLegendItem('Other', '$other', _gray),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showViolationFormDialog(dynamic existing) async {
    await _ensureLookupsLoaded();
    if (!mounted) return;

    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final Map<String, dynamic> uniqueDrivers = {};
    for (final d in _drivers) {
      final id = d['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueDrivers[id] = d;
    }

    final Map<String, dynamic> uniqueVehicles = {};
    for (final v in _vehicles) {
      final id = v['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueVehicles[id] = v;
    }

    String? selectedDriverId = existing?['driver_id']?.toString();
    if (selectedDriverId != null && !uniqueDrivers.containsKey(selectedDriverId)) {
      selectedDriverId = null;
    }

    String? selectedVehicleId = existing?['vehicle_id']?.toString() ?? existing?['drivers']?['assigned_vehicle_id']?.toString() ?? existing?['drivers']?['vehicle_id']?.toString();
    if (selectedVehicleId != null && !uniqueVehicles.containsKey(selectedVehicleId)) {
      selectedVehicleId = null;
    }

    String type = existing?['violation_type'] ?? 'Overspeeding';
    String severity = existing?['severity'] ?? 'Medium';
    String status = existing?['status'] ?? 'Pending';
    final dateController = TextEditingController(text: existing?['date_time'] ?? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()));
    final locationController = TextEditingController(text: existing?['location']);
    final fineController = TextEditingController(text: existing?['fine_amount']?.toString() ?? '1000');
    final descController = TextEditingController(text: existing?['description']);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Violation Record' : 'Log New Violation', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    clipBehavior: Clip.none,
                    shrinkWrap: true,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedDriverId,
                        decoration: const InputDecoration(labelText: 'Driver *', border: OutlineInputBorder()),
                        items: uniqueDrivers.values.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['name'] ?? 'Driver'} (${d['driver_code'] ?? 'DRV'})'))).toList(),
                        validator: (val) => val == null ? 'Required' : null,
                        onChanged: isEdit ? null : (val) => setDialogState(() => selectedDriverId = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVehicleId,
                        decoration: const InputDecoration(labelText: 'Vehicle Involved *', border: OutlineInputBorder()),
                        items: uniqueVehicles.values.map((v) {
                          final label = '${v['registration_no'] ?? v['bus_number'] ?? 'Bus'} (${v['route_name'] ?? 'Route'})';
                          return DropdownMenuItem<String>(value: v['id'].toString(), child: Text(label));
                        }).toList(),
                        validator: (val) => val == null ? 'Required' : null,
                        onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: type,
                              decoration: const InputDecoration(labelText: 'Violation Type', border: OutlineInputBorder()),
                              items: ['Overspeeding', 'Signal Jump', 'Seat Belt Not Worn', 'Mobile Usage', 'Harsh Braking', 'Wrong Route', 'Overtime Driving', 'Parking Violation'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => type = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: severity,
                              decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                              items: ['High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => severity = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dateController,
                              decoration: InputDecoration(
                                labelText: 'Date & Time *', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, dateController)),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: fineController,
                              decoration: const InputDecoration(labelText: 'Fine Amount (\u{20B9}) *', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                        items: ['Pending', 'Resolved', 'Cancelled', 'Waived'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setDialogState(() => status = val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Location / Highway *', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description / Details', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Parse date time
                      String dtValue = dateController.text;
                      if (!dtValue.contains('T') && dtValue.length == 10) {
                        dtValue = '${dtValue}T12:00:00Z';
                      } else if (dtValue.length == 16) {
                        dtValue = '${dtValue.replaceFirst(' ', 'T')}:00Z';
                      }

                      final data = {
                        "school_id": widget.schoolId ?? '11111111-1111-1111-1111-111111111111',
                        "driver_id": selectedDriverId,
                        "vehicle_id": selectedVehicleId,
                        "violation_type": type,
                        "severity": severity,
                        "date_time": dtValue,
                        "fine_amount": double.tryParse(fineController.text) ?? 1000.0,
                        "status": status,
                        "location": locationController.text,
                        "description": descController.text.isNotEmpty ? descController.text : null,
                      };

                      try {
                        if (isEdit) {
                          await ApiService().put('/transport/drivers/violations/${existing['id']}', data);
                        } else {
                          await ApiService().post('/transport/drivers/violations', data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Violation updated successfully' : 'Violation logged successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save violation: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save' : 'Log Violation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteViolation(dynamic viol) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove Violation Record', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to remove/delete this violation record? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/drivers/violations/${viol['id']}');
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedViolation = null;
                  });
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Violation record deleted'), backgroundColor: _green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete violation: $e'), backgroundColor: _red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaginationRow(
    int totalCount,
    int startIndex,
    int paginatedLength,
    int pageSize,
    int currentPage,
    Function(int) onPageChanged,
    Function(int) onPageSizeChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1} to ${startIndex + paginatedLength > totalCount ? totalCount : startIndex + paginatedLength} of $totalCount records',
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(6)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: pageSize,
                    items: [5, 10, 20, 50].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size / page', style: GoogleFonts.inter(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) onPageSizeChanged(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Text('$currentPage', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: startIndex + paginatedLength < totalCount ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '${hour.toString().padLeft(2, '0')}:$minute $period';
    }
  }

  void _showAllDocumentsModal({String? filterDriverId}) {
    showDialog(
      context: context,
      builder: (ctx) {
        final docs = filterDriverId == null
            ? _driverDocuments
            : _driverDocuments.where((doc) => doc['driver_id']?.toString() == filterDriverId).toList();
        
        final driverName = filterDriverId == null
            ? "All Drivers"
            : (_drivers.firstWhere((d) => d['id'].toString() == filterDriverId, orElse: () => {})['name'] ?? 'Selected Driver');

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 850,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Document Registry - $driverName', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text('No documents found for this driver.'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Driver', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Document Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Document Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Issuing Authority', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Issue Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: docs.map<DataRow>((d) {
                                final drv = _drivers.firstWhere((drv) => drv['id'].toString() == d['driver_id']?.toString(), orElse: () => {});
                                final status = d['status'] ?? 'Valid';
                                final statusColor = status == 'Valid' ? _green : _red;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(drv['name'] ?? '—')),
                                    DataCell(Text(d['document_type'] ?? '—')),
                                    DataCell(Text(d['document_no'] ?? '—')),
                                    DataCell(Text(d['issuing_authority'] ?? '—')),
                                    DataCell(Text(_formatDate(d['issued_date']))),
                                    DataCell(Text(_formatDate(d['expiry_date']))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                        child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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

  // ──────── Direct File Upload (no popup) ────────
  Future<void> _directUploadDocument(dynamic doc) async {
    try {
      // Open file picker directly — no popup
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return; // user cancelled

      // Show uploading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 12),
                Text('Uploading ${file.name}...', style: const TextStyle(color: Colors.white)),
              ],
            ),
            backgroundColor: _accent,
            duration: const Duration(seconds: 10),
          ),
        );
      }

      final bytes = await file.readAsBytes();
      final response = await ApiService().multipartPostBytes(
        '/transport/documents/upload',
        bytes,
        file.name,
        'file',
      );

      // Dismiss the uploading snackbar
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final uploadedUrl = response['data']?['url'] ?? response['url'] ?? '';

      // Patch the existing document record with the new attachment
      final updateData = {
        ...Map<String, dynamic>.from(doc as Map),
        'file_url': uploadedUrl.isNotEmpty ? uploadedUrl : doc['file_url'],
        'file_name': file.name,
        'file_size': bytes.length,
      };
      updateData.remove('id');
      updateData.remove('created_at');
      updateData.remove('updated_at');
      updateData.remove('drivers');

      await ApiService().put('/transport/drivers/documents/${doc['id']}', updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Attachment updated: ${file.name}'),
            backgroundColor: _green,
          ),
        );
        _loadData(); // refresh grid and details
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: _red),
        );
      }
    }
  }

  // ──────── Document CRUD Dialogs ────────
  Future<void> _showDocumentFormDialog(dynamic existing) async {
    await _ensureLookupsLoaded();
    if (!mounted) return;

    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final Map<String, dynamic> uniqueDrivers = {};
    for (final d in _drivers) {
      final id = d['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueDrivers[id] = d;
    }

    String? selectedDriverId = existing?['driver_id']?.toString();
    if (selectedDriverId != null && !uniqueDrivers.containsKey(selectedDriverId)) {
      selectedDriverId = null;
    }

    String docType = existing?['document_type'] ?? 'Driving License';
    final allowedTypes = ['Driving License', 'Badge', 'Police Verification', 'Aadhaar Card', 'Medical Certificate', 'Fitness Certificate', 'Pollution Certificate'];
    if (!allowedTypes.contains(docType)) docType = 'Driving License';

    String status = existing?['status'] ?? 'Valid';
    final allowedStatuses = ['Valid', 'Expiring Soon', 'Expired', 'Permanent'];
    if (!allowedStatuses.contains(status)) status = 'Valid';

    final docNoController = TextEditingController(text: existing?['document_no']);
    final authorityController = TextEditingController(text: existing?['issuing_authority'] ?? 'RTO');
    final issueDateController = TextEditingController(text: existing?['issued_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final expiryDateController = TextEditingController(text: existing?['expiry_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 365))));
    final fileUrlController = TextEditingController(text: existing?['file_url'] ?? '');
    
    String fileName = existing?['file_name'] ?? '';
    int? fileSize = existing?['file_size'];
    bool isUploading = false;
    String? uploadError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Document' : 'Upload / Add Driver Document', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    clipBehavior: Clip.none,
                    shrinkWrap: true,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedDriverId,
                        decoration: const InputDecoration(labelText: 'Select Driver *', border: OutlineInputBorder()),
                        items: uniqueDrivers.values.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['name'] ?? 'Driver'} (${d['driver_code'] ?? 'DRV'})'))).toList(),
                        validator: (val) => val == null ? 'Required' : null,
                        onChanged: (val) => setDialogState(() => selectedDriverId = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: docType,
                              decoration: const InputDecoration(labelText: 'Document Type *', border: OutlineInputBorder()),
                              items: ['Driving License', 'Badge', 'Police Verification', 'Aadhaar Card', 'Medical Certificate', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => docType = val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
                              items: ['Valid', 'Expiring Soon', 'Expired', 'Permanent'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => status = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: docNoController,
                        decoration: const InputDecoration(labelText: 'Document Number *', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: issueDateController,
                              decoration: InputDecoration(
                                labelText: 'Issue Date (YYYY-MM-DD)',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, issueDateController)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: expiryDateController,
                              decoration: InputDecoration(
                                labelText: 'Expiry Date (YYYY-MM-DD)',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, expiryDateController)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: authorityController,
                        decoration: const InputDecoration(labelText: 'Issuing Authority', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fileUrlController,
                        decoration: const InputDecoration(labelText: 'File URL / Attachment Path', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Text('Document File Attachment', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: _textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: isUploading ? null : () async {
                              try {
                                final file = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (file != null) {
                                  setDialogState(() {
                                    isUploading = true;
                                    uploadError = null;
                                  });
                                  final bytes = await file.readAsBytes();
                                  final response = await ApiService().multipartPostBytes(
                                    '/transport/documents/upload',
                                    bytes,
                                    file.name,
                                    'file',
                                  );
                                  if (response['success'] == true) {
                                    setDialogState(() {
                                      final url = response['data']?['url'] ?? '';
                                      fileUrlController.text = url;
                                      fileName = file.name;
                                      fileSize = bytes.length;
                                      isUploading = false;
                                    });
                                  } else {
                                    setDialogState(() {
                                      uploadError = 'Upload failed';
                                      isUploading = false;
                                    });
                                  }
                                }
                              } catch (e) {
                                setDialogState(() {
                                  uploadError = e.toString();
                                  isUploading = false;
                                });
                              }
                            },
                            icon: isUploading
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _accent))
                                : const Icon(Icons.attach_file, size: 16),
                            label: Text(isUploading ? 'Uploading...' : 'Attach File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent.withValues(alpha: 0.1),
                              foregroundColor: _accent,
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName.isNotEmpty ? fileName : 'No file chosen',
                              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (uploadError != null) ...[
                        const SizedBox(height: 4),
                        Text(uploadError!, style: GoogleFonts.inter(color: _red, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        "school_id": widget.schoolId ?? '11111111-1111-1111-1111-111111111111',
                        "driver_id": selectedDriverId,
                        "document_type": docType,
                        "document_no": docNoController.text,
                        "issued_date": issueDateController.text.isNotEmpty ? issueDateController.text : null,
                        "expiry_date": status == 'Permanent' ? null : (expiryDateController.text.isNotEmpty ? expiryDateController.text : null),
                        "issuing_authority": authorityController.text.isNotEmpty ? authorityController.text : 'RTO',
                        "status": status,
                        "file_url": fileUrlController.text.isNotEmpty ? fileUrlController.text : null,
                        "file_name": fileName.isNotEmpty ? fileName : '${docType.replaceAll(' ', '_')}.pdf',
                        "file_size": fileSize,
                      };
                      try {
                        if (isEdit) {
                          await ApiService().put('/transport/drivers/documents/${existing['id']}', data);
                        } else {
                          await ApiService().post('/transport/drivers/documents', data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Document updated successfully' : 'Document uploaded successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save document: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Upload Document'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDocument(dynamic doc) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Document', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete ${doc['document_type']} (${doc['document_no']})? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/drivers/documents/${doc['id']}');
                  Navigator.pop(ctx);
                  setState(() => _selectedDocument = null);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document deleted successfully'), backgroundColor: _green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete document: $e'), backgroundColor: _red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }



  // ──────── Performance CRUD & Export Dialogs ────────
  Future<void> _showPerformanceFormDialog(dynamic existing) async {
    await _ensureLookupsLoaded();
    if (!mounted) return;

    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final Map<String, dynamic> uniqueDrivers = {};
    for (final d in _drivers) {
      final id = d['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueDrivers[id] = d;
    }

    final Map<String, dynamic> uniqueVehicles = {};
    for (final v in _vehicles) {
      final id = v['id']?.toString();
      if (id != null && id.isNotEmpty) uniqueVehicles[id] = v;
    }

    String? selectedDriverId = existing?['driver_id']?.toString();
    if (selectedDriverId != null && !uniqueDrivers.containsKey(selectedDriverId)) {
      selectedDriverId = null;
    }

    String? selectedVehicleId = existing?['vehicle_id']?.toString() ?? existing?['drivers']?['assigned_vehicle_id']?.toString() ?? existing?['drivers']?['vehicle_id']?.toString();
    if (selectedVehicleId != null && !uniqueVehicles.containsKey(selectedVehicleId)) {
      selectedVehicleId = null;
    }

    final attController = TextEditingController(text: existing?['attendance_score']?.toString() ?? '4.8');
    final safController = TextEditingController(text: existing?['safety_score']?.toString() ?? '4.5');
    final rtController = TextEditingController(text: existing?['route_adherence_score']?.toString() ?? '4.7');
    final vcController = TextEditingController(text: existing?['vehicle_care_score']?.toString() ?? '4.6');
    final fbController = TextEditingController(text: existing?['feedback_score']?.toString() ?? '4.8');
    final tripsController = TextEditingController(text: existing?['trips_completed']?.toString() ?? '120');
    final remarksController = TextEditingController(text: existing?['remarks']);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Performance Score' : 'Add Driver Performance Record', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    clipBehavior: Clip.none,
                    shrinkWrap: true,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedDriverId,
                        decoration: const InputDecoration(labelText: 'Select Driver *', border: OutlineInputBorder()),
                        items: uniqueDrivers.values.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['name'] ?? 'Driver'} (${d['driver_code'] ?? 'DRV'})'))).toList(),
                        validator: (val) => val == null ? 'Required' : null,
                        onChanged: (val) => setDialogState(() => selectedDriverId = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVehicleId,
                        decoration: const InputDecoration(labelText: 'Vehicle Assigned', border: OutlineInputBorder()),
                        items: uniqueVehicles.values.map((v) => DropdownMenuItem<String>(value: v['id'].toString(), child: Text('${v['registration_no'] ?? v['bus_number'] ?? 'Bus'} (${v['vehicle_type'] ?? 'Bus'})'))).toList(),
                        onChanged: (val) => setDialogState(() => selectedVehicleId = val),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: attController,
                              decoration: const InputDecoration(labelText: 'Attendance Score (0-5)', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: safController,
                              decoration: const InputDecoration(labelText: 'Safety Score (0-5)', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: rtController,
                              decoration: const InputDecoration(labelText: 'Route Adherence (0-5)', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: vcController,
                              decoration: const InputDecoration(labelText: 'Vehicle Care (0-5)', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: fbController,
                              decoration: const InputDecoration(labelText: 'Parent Feedback (0-5)', border: OutlineInputBorder()),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: tripsController,
                              decoration: const InputDecoration(labelText: 'Trips Completed', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: remarksController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Performance Remarks', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        "school_id": widget.schoolId ?? '11111111-1111-1111-1111-111111111111',
                        "driver_id": selectedDriverId,
                        "vehicle_id": selectedVehicleId,
                        "attendance_score": double.tryParse(attController.text) ?? 4.5,
                        "safety_score": double.tryParse(safController.text) ?? 4.5,
                        "route_adherence_score": double.tryParse(rtController.text) ?? 4.5,
                        "vehicle_care_score": double.tryParse(vcController.text) ?? 4.5,
                        "feedback_score": double.tryParse(fbController.text) ?? 4.5,
                        "trips_completed": int.tryParse(tripsController.text) ?? 100,
                        "remarks": remarksController.text.isNotEmpty ? remarksController.text : null,
                      };
                      try {
                        final messenger = ScaffoldMessenger.of(context);
                        if (isEdit) {
                          await ApiService().put('/transport/drivers/performance/${existing['id']}', data);
                        } else {
                          await ApiService().post('/transport/drivers/performance', data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                        messenger.showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Performance score updated successfully' : 'Performance record added successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save performance score: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Add Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePerformance(dynamic perf) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Performance Record', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this performance record? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/drivers/performance/${perf['id']}');
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Performance record deleted successfully'), backgroundColor: _green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete performance record: $e'), backgroundColor: _red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _exportPerformanceReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting Driver Performance Report (CSV)...'), backgroundColor: _green),
    );
  }



  // ═══════════════════ Dialogs & Actions ═══════════════════
  void _showDriverDetailsDialog(dynamic dev) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: Text(dev['name'] ?? 'Driver Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    automaticallyImplyLeading: false,
                    actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))],
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  _buildDetailsPanelSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showAddDriverDialog() {
    _showDriverFormDialog(null);
  }

  void showEditDriverDialog(dynamic dev) {
    _showDriverFormDialog(dev);
  }

  void _showDriverFormDialog(dynamic existing) {
    final bool isEdit = existing != null;
    final formKey = GlobalKey<FormState>();

    final codeController = TextEditingController(text: existing?['driver_code'] ?? 'DRV-${_drivers.length + 1001}');
    final nameController = TextEditingController(text: existing?['name']);
    final emailController = TextEditingController(text: existing?['email']);
    final phoneController = TextEditingController(text: existing?['phone']);
    final licController = TextEditingController(text: existing?['license_no']);
    final authorityController = TextEditingController(text: existing?['issuing_authority'] ?? 'RTO Noida');
    final expController = TextEditingController(text: existing?['experience_years']?.toString() ?? '5');
    
    // Dates
    final dobController = TextEditingController(text: existing?['date_of_birth'] ?? '1990-01-01');
    final joinedController = TextEditingController(text: existing?['joined_date'] ?? '2024-01-01');
    final licIssueController = TextEditingController(text: existing?['license_issue_date'] ?? '2020-01-01');
    final licExpiryController = TextEditingController(text: existing?['license_expiry_date'] ?? '2030-01-01');

    final bloodController = TextEditingController(text: existing?['blood_group'] ?? 'B+');
    final aadharController = TextEditingController(text: existing?['aadhar_no'] ?? 'XXXX XXXX 1234');
    final addressController = TextEditingController(text: existing?['address'] ?? 'Sector 62, Noida, UP');

    String licenseType = existing?['license_type'] ?? 'LMV';
    String status = existing?['status'] ?? 'Active';
    String? assignedVehicleId = existing?['assigned_vehicle_id'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Driver Details' : 'Add New Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                height: 520,
                child: Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 10, bottom: 6),
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeController,
                              decoration: const InputDecoration(labelText: 'Driver Code *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: emailController,
                              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: licController,
                              decoration: const InputDecoration(labelText: 'License Number *', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: licenseType,
                              decoration: const InputDecoration(labelText: 'License Type', border: OutlineInputBorder()),
                              items: ['LMV', 'HMV'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => licenseType = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: expController,
                              decoration: const InputDecoration(labelText: 'Experience (Years)', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: status,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                              items: ['Active', 'On Duty', 'On Leave', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (val) => setDialogState(() => status = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dobController,
                              decoration: InputDecoration(
                                labelText: 'Date of Birth (YYYY-MM-DD)', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, dobController)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: bloodController,
                              decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: licIssueController,
                              decoration: InputDecoration(
                                labelText: 'License Issue Date', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, licIssueController)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: licExpiryController,
                              decoration: InputDecoration(
                                labelText: 'License Expiry Date', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, licExpiryController)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: authorityController,
                              decoration: const InputDecoration(labelText: 'Issuing Authority', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: joinedController,
                              decoration: InputDecoration(
                                labelText: 'Joined Date', 
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, size: 16), onPressed: () => _selectDate(context, joinedController)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: assignedVehicleId,
                        decoration: const InputDecoration(labelText: 'Assign Vehicle', border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('Unassigned / None')),
                          ..._vehicles.map((v) {
                            final label = '${v['registration_no'] ?? v['bus_number'] ?? 'Bus'} (${v['vehicle_type'] ?? 'Bus'})';
                            return DropdownMenuItem<String>(value: v['id'].toString(), child: Text(label));
                          }),
                        ],
                        onChanged: (val) => setDialogState(() => assignedVehicleId = val),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: aadharController,
                        decoration: const InputDecoration(labelText: 'Aadhar Card Number', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        "school_id": widget.schoolId ?? '11111111-1111-1111-1111-111111111111',
                        "driver_code": codeController.text,
                        "name": nameController.text,
                        "phone": phoneController.text,
                        "email": emailController.text.isNotEmpty ? emailController.text : null,
                        "license_no": licController.text,
                        "license_type": licenseType,
                        "experience_years": int.tryParse(expController.text) ?? 5,
                        "status": status,
                        "assigned_vehicle_id": assignedVehicleId,
                        "issuing_authority": authorityController.text,
                        "date_of_birth": dobController.text,
                        "blood_group": bloodController.text,
                        "aadhar_no": aadharController.text,
                        "address": addressController.text,
                        "joined_date": joinedController.text,
                        "license_issue_date": licIssueController.text,
                        "license_expiry_date": licExpiryController.text,
                      };

                      try {
                        if (isEdit) {
                          await ApiService().put('/transport/drivers/${existing['id']}', data);
                        } else {
                          await ApiService().post('/transport/drivers', data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isEdit ? 'Driver updated successfully' : 'Driver added successfully'), backgroundColor: _green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save driver details: $e'), backgroundColor: _red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                  child: Text(isEdit ? 'Save Changes' : 'Add Driver'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteDriver(dynamic dev) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete driver ${dev['name']} (${dev['driver_code']})? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().delete('/transport/drivers/${dev['id']}');
                  Navigator.pop(ctx);
                  if (_selectedDriver != null && _selectedDriver['id'] == dev['id']) {
                    setState(() {
                      _selectedDriver = null;
                    });
                  }
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Driver deleted successfully'), backgroundColor: _green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete driver: $e'), backgroundColor: _red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
