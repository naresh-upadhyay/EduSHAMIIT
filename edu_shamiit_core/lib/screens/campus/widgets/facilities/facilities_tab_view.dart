import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../providers/campus_provider.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';
import '../../models/campus_models.dart';
import '../common/campus_pagination_bar.dart';
import 'dialogs/add_edit_facility_dialog.dart';

class FacilitiesTabView extends ConsumerStatefulWidget {
  const FacilitiesTabView({super.key});

  @override
  ConsumerState<FacilitiesTabView> createState() => _FacilitiesTabViewState();
}

class _FacilitiesTabViewState extends ConsumerState<FacilitiesTabView> {
  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Statuses';
  int _viewMode = 0; // 0: Grid cards, 1: Table
  bool _isLoading = true;
  int _page = 1;
  int _pageSize = 10;
  int? _sortColIndex = 0;
  bool _sortAsc = true;

  List<Map<String, dynamic>> _facilities = [];
  List<String> _categories = ['All Categories'];
  List<String> _statuses = ['All Statuses'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Fetch dynamic lookup categories
    final catLookups = await CampusLookupHelper.instance.getLookupLabels(
      'FACILITY_TYPE',
      defaultLabels: [
        'Sports Complex / Ground',
        'Specialized Laboratory',
        'Auditorium & Amphitheater',
        'Library & Learning Commons',
        'Dining & Cafeteria Hub',
        'Health Center & Clinic',
        'Transport Hub & Bus Bay',
        'Robotics & Fabrication Lab',
        'Indoor Gymnasium & Yoga Studio',
        'Student Activity Center',
      ],
    );

    final statLookups = await CampusLookupHelper.instance.getLookupLabels(
      'FACILITY_STATUS',
      defaultLabels: [
        'Operational',
        'Under Maintenance',
        'Reserved / In-Use',
        'Temporarily Closed',
      ],
    );

    // Fetch facilities from database via dedicated Campus API
    final facRes = await CampusApiService.instance.getFacilities(page: 1, pageSize: 100);
    final facList = (facRes['data'] as List<dynamic>?) ?? [];

    List<Map<String, dynamic>> facs = [];
    if (facList.isNotEmpty) {
      facs = facList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      // Fallback: Fetch rooms that act as institutional facilities
      final roomsRes = await CampusApiService.instance.getRooms(page: 1, pageSize: 50);
      final roomsList = (roomsRes['data'] as List<RoomModel>?) ?? [];

      if (roomsList.isNotEmpty) {
        facs = roomsList.map((r) {
          String cat = 'Specialized Laboratory';
          if (r.roomType.toLowerCase().contains('lab')) {
            cat = 'Specialized Laboratory';
          } else if (r.roomType.toLowerCase().contains('auditorium') || r.roomType.toLowerCase().contains('hall')) {
            cat = 'Auditorium & Amphitheater';
          } else if (r.roomType.toLowerCase().contains('library')) {
            cat = 'Library & Learning Commons';
          } else if (r.roomType.toLowerCase().contains('sports') || r.roomType.toLowerCase().contains('gym')) {
            cat = 'Sports Complex / Ground';
          } else if (r.roomType.toLowerCase().contains('canteen') || r.roomType.toLowerCase().contains('dining')) {
            cat = 'Dining & Cafeteria Hub';
          } else if (r.roomType.toLowerCase().contains('medical') || r.roomType.toLowerCase().contains('clinic')) {
            cat = 'Health Center & Clinic';
          } else {
            cat = 'Student Activity Center';
          }

          return {
            'id': r.id,
            'name': r.name.isNotEmpty ? r.name : 'Room ${r.roomNumber}',
            'code': r.roomCode.isNotEmpty ? r.roomCode : r.roomNumber,
            'category': cat,
            'status': r.operationalStatus == 'Available' ? 'Operational' : (r.operationalStatus == 'Under Maintenance' ? 'Under Maintenance' : 'Reserved / In-Use'),
            'building_id': r.buildingId,
            'building_name': r.buildingName ?? 'Academic Complex',
            'floor_name': r.floorName ?? 'Floor ${r.floorLevel ?? 1}',
            'capacity': r.maxCapacity,
            'area': r.area > 0 ? r.area : 1200.0,
            'manager_name': r.responsiblePersonName ?? 'Campus Facility Officer',
            'manager_phone': '+91 98765 43210',
            'equipment_count': r.equipmentCount,
            'description': r.description ?? 'Institutional infrastructure facility for student and academic use.',
          };
        }).toList();
      }
    }

    // Include standard institutional campus facilities if list is small
    if (facs.length < 4) {
      facs.addAll([
        {
          'id': 'fac-1',
          'name': 'Main Athletic Complex & Football Ground',
          'code': 'SPT-FLD-01',
          'category': 'Sports Complex / Ground',
          'status': 'Operational',
          'building_name': 'Outdoor Campus Sports Ground',
          'floor_name': 'Ground Level',
          'capacity': 1200,
          'area': 65000.0,
          'manager_name': 'Coach R. K. Singh',
          'manager_phone': '+91 98450 11223',
          'equipment_count': 24,
          'description': 'FIFA regulation grass turf field with 400m synthetic running track and floodlighting.',
        },
        {
          'id': 'fac-2',
          'name': 'Dr. APJ Abdul Kalam Central Auditorium',
          'code': 'AUD-01',
          'category': 'Auditorium & Amphitheater',
          'status': 'Operational',
          'building_name': 'B4 - Auditorium Block',
          'floor_name': 'Ground & Mezzanine',
          'capacity': 850,
          'area': 9500.0,
          'manager_name': 'Deepak Malhotra',
          'manager_phone': '+91 98220 44556',
          'equipment_count': 42,
          'description': 'State-of-the-art acoustic auditorium with 4K laser projection and line array audio system.',
        },
        {
          'id': 'fac-3',
          'name': 'Central Robotics & IoT Innovation FabLab',
          'code': 'LAB-ROB-01',
          'category': 'Robotics & Fabrication Lab',
          'status': 'Operational',
          'building_name': 'B1 - Academic Block (A)',
          'floor_name': 'Third Floor',
          'capacity': 60,
          'area': 2400.0,
          'manager_name': 'Dr. S. Mukherjee',
          'manager_phone': '+91 98771 99881',
          'equipment_count': 68,
          'description': 'Advanced prototyping lab with 3D printers, laser cutters, oscilloscope stations, and robotic arms.',
        },
        {
          'id': 'fac-4',
          'name': 'Central Food Court & Dining Hall',
          'code': 'CAN-01',
          'category': 'Dining & Cafeteria Hub',
          'status': 'Operational',
          'building_name': 'Student Amenities Block',
          'floor_name': 'Ground Floor',
          'capacity': 500,
          'area': 7200.0,
          'manager_name': 'Vikram Rathore',
          'manager_phone': '+91 98110 33445',
          'equipment_count': 18,
          'description': 'Hygienic institutional kitchen and dining hall serving students and faculty.',
        },
      ]);
    }

    if (mounted) {
      setState(() {
        _categories = ['All Categories', ...catLookups];
        _statuses = ['All Statuses', ...statLookups];
        _facilities = facs;
        _isLoading = false;
      });
    }
  }

  void _openAddFacilityModal([Map<String, dynamic>? facility]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditFacilityDialog(
        facility: facility,
        onSaved: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(facility == null ? 'Facility registered successfully!' : 'Facility updated successfully!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteFacility(Map<String, dynamic> f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Facility'),
        content: Text('Are you sure you want to delete "${f['name']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final res = await CampusApiService.instance.deleteFacility(f['id'].toString());
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Facility deleted successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Failed to delete facility'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final bgCard = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filtered = _facilities.where((f) {
      if (_selectedCategory != 'All Categories' && f['category'] != _selectedCategory) return false;
      if (_selectedStatus != 'All Statuses' && f['status'] != _selectedStatus) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (f['name'] ?? '').toString().toLowerCase();
        final code = (f['code'] ?? '').toString().toLowerCase();
        final cat = (f['category'] ?? '').toString().toLowerCase();
        final bld = (f['building_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q) || cat.contains(q) || bld.contains(q);
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColIndex) {
        case 0:
          cmp = (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
          break;
        case 1:
          cmp = (a['category'] ?? '').toString().compareTo((b['category'] ?? '').toString());
          break;
        case 2:
          cmp = (a['building_name'] ?? '').toString().compareTo((b['building_name'] ?? '').toString());
          break;
        case 3:
          cmp = ((a['capacity'] as num?) ?? 0).compareTo((b['capacity'] as num?) ?? 0);
          break;
        case 4:
          cmp = (a['manager_name'] ?? '').toString().compareTo((b['manager_name'] ?? '').toString());
          break;
        case 5:
          cmp = (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString());
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totalFiltered = filtered.length;
    final totalPages = math.max(1, (totalFiltered / _pageSize).ceil());
    if (_page > totalPages) _page = totalPages;

    final startIndex = (totalFiltered == 0) ? 0 : (_page - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalFiltered);
    final pagedItems = (startIndex < totalFiltered) ? filtered.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    final totalCount = _facilities.length;
    final operationalCount = _facilities.where((f) => f['status'] == 'Operational').length;
    final bookedCount = _facilities.where((f) => f['status'] == 'Reserved / In-Use').length;
    final maintenanceCount = _facilities.where((f) => f['status'] == 'Under Maintenance').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Facilities KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;
                if (isCompact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildKpiCard('Total Facilities', '$totalCount', Icons.domain_rounded, primaryColor, isDark)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildKpiCard('Operational', '$operationalCount', Icons.check_circle_rounded, const Color(0xFF10B981), isDark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildKpiCard('Reserved / In-Use', '$bookedCount', Icons.event_available_rounded, const Color(0xFF3B82F6), isDark)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildKpiCard('Maintenance', '$maintenanceCount', Icons.build_circle_rounded, const Color(0xFFF59E0B), isDark)),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: _buildKpiCard('Total Facilities', '$totalCount', Icons.domain_rounded, primaryColor, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Operational', '$operationalCount', Icons.check_circle_rounded, const Color(0xFF10B981), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Reserved / In-Use', '$bookedCount', Icons.event_available_rounded, const Color(0xFF3B82F6), isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKpiCard('Maintenance', '$maintenanceCount', Icons.build_circle_rounded, const Color(0xFFF59E0B), isDark)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Search, Filter and Actions Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Search Input
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search facilities...',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                      ),
                      style: TextStyle(fontSize: 12.5, color: textPrimary),
                    ),
                  ),

                  // Category Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isDense: true,
                        dropdownColor: bgCard,
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(fontSize: 12, color: textPrimary)))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val ?? 'All Categories'),
                      ),
                    ),
                  ),

                  // Status Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isDense: true,
                        dropdownColor: bgCard,
                        items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, color: textPrimary)))).toList(),
                        onChanged: (val) => setState(() => _selectedStatus = val ?? 'All Statuses'),
                      ),
                    ),
                  ),

                  // View Switcher & Add Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.grid_view_rounded, size: 18, color: _viewMode == 0 ? primaryColor : textSecondary),
                        tooltip: 'Card Grid View',
                        onPressed: () => setState(() => _viewMode = 0),
                      ),
                      IconButton(
                        icon: Icon(Icons.table_rows_rounded, size: 18, color: _viewMode == 1 ? primaryColor : textSecondary),
                        tooltip: 'Table View',
                        onPressed: () => setState(() => _viewMode = 1),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () => _openAddFacilityModal(),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('Add Facility', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Main Facilities Grid / Table
            if (_isLoading)
              const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text('No campus facilities match the selected filters.', style: TextStyle(fontSize: 14, color: textSecondary)),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'All Categories';
                        _selectedStatus = 'All Statuses';
                      }),
                      child: const Text('Reset Filters'),
                    ),
                  ],
                ),
              )
            else if (_viewMode == 0)
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 3;
                  if (constraints.maxWidth < 750) {
                    crossAxisCount = 1;
                  } else if (constraints.maxWidth < 1150) {
                    crossAxisCount = 2;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pagedItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 260,
                    ),
                    itemBuilder: (context, idx) {
                      final item = pagedItems[idx];
                      return _buildFacilityCard(item, primaryColor, bgCard, borderColor, textPrimary, textSecondary, isDark);
                    },
                  );
                },
              )
            else
              // Table View
              Container(
                decoration: BoxDecoration(
                  color: bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 800),
                    child: DataTable(
                      headingRowHeight: 34,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 35,
                      horizontalMargin: 12,
                      columnSpacing: 16,
                      sortColumnIndex: _sortColIndex,
                      sortAscending: _sortAsc,
                      columns: [
                        DataColumn(
                          label: const Text('Code / Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('Location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          numeric: true,
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('Supervisor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        DataColumn(
                          label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          onSort: (col, asc) => setState(() { _sortColIndex = col; _sortAsc = asc; }),
                        ),
                        const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                      ],
                      rows: pagedItems.map((f) {
                        final isOp = f['status'] == 'Operational';
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              '${f['code']} - ${f['name']}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            )),
                            DataCell(Text(f['category'] ?? '', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('${f['building_name']} - ${f['floor_name']}', style: const TextStyle(fontSize: 11.5))),
                            DataCell(Text('${f['capacity'] ?? 0} seats', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(f['manager_name'] ?? '-', style: const TextStyle(fontSize: 12))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isOp ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                f['status'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOp ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 15),
                                  tooltip: 'Edit Facility',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  onPressed: () => _openAddFacilityModal(f),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                                  tooltip: 'Delete Facility',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  onPressed: () => _deleteFacility(f),
                                ),
                                IconButton(
                                  icon: Icon(Icons.event_seat_rounded, size: 15, color: primaryColor),
                                  tooltip: 'Book in Space Booking',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                  onPressed: () {
                                    ref.read(campusProvider.notifier).setActiveCampusTab(2); // Jump to Space Booking
                                  },
                                ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

            // 4. Pagination Bar
            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 8),
              CampusPaginationBar(
                currentPage: _page,
                pageSize: _pageSize,
                totalItems: totalFiltered,
                onPageChanged: (newPage) => setState(() => _page = newPage),
                onPageSizeChanged: (newSize) => setState(() {
                  _pageSize = newSize;
                  _page = 1;
                }),
                itemLabel: 'facilities',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityCard(
    Map<String, dynamic> f,
    Color primaryColor,
    Color bgCard,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final isOp = f['status'] == 'Operational';
    final statusColor = isOp ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category badge & Status pill
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  f['category'] ?? 'Facility',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      f['status'] ?? '',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name & Code
          Text(
            f['name'] ?? '',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${f['code']} • ${f['building_name']}',
            style: TextStyle(fontSize: 11.5, color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Metrics row: Capacity & Area & Equipment
          Row(
            children: [
              _buildMetricChip(Icons.people_alt_outlined, '${f['capacity']} Seats', textSecondary, isDark),
              const SizedBox(width: 8),
              _buildMetricChip(Icons.square_foot_rounded, '${f['area']} sq ft', textSecondary, isDark),
              const SizedBox(width: 8),
              _buildMetricChip(Icons.precision_manufacturing_outlined, '${f['equipment_count']} Items', textSecondary, isDark),
            ],
          ),
          const SizedBox(height: 8),

          // Supervisor
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${f['manager_name']} (${f['manager_phone']})',
                  style: TextStyle(fontSize: 11, color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 12),

          // Quick Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _openAddFacilityModal(f),
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _deleteFacility(f),
                    icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                    tooltip: 'Delete Facility',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(campusProvider.notifier).setActiveCampusTab(3); // Jump to Maintenance
                    },
                    icon: const Icon(Icons.build_rounded, size: 12),
                    label: const Text('Report Issue', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(campusProvider.notifier).setActiveCampusTab(2); // Jump to Space Booking
                    },
                    icon: const Icon(Icons.calendar_month, size: 12, color: Colors.white),
                    label: const Text('Book Space', style: TextStyle(fontSize: 11, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10.5, color: textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
