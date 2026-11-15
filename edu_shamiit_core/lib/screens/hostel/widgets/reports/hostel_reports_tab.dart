import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_report_print_preview_dialog.dart';
import 'hostel_turnover_forecast_card.dart';

class HostelReportsTab extends ConsumerStatefulWidget {
  const HostelReportsTab({super.key});

  @override
  ConsumerState<HostelReportsTab> createState() => _HostelReportsTabState();
}

class _HostelReportsTabState extends ConsumerState<HostelReportsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  int _currentPage = 1;
  int _pageSize = 10;
  String _sortColumnKey = '';
  bool _sortAscending = true;
  int? _sortColumnIndex;

  final List<Map<String, dynamic>> _reportCategories = [
    {
      'id': 'occupancy',
      'title': 'Occupancy Master',
      'subtitle': 'Building, room capacities, vacant beds, and operational status',
      'icon': Icons.apartment_rounded,
      'color': const Color(0xFF2563EB),
    },
    {
      'id': 'residents',
      'title': 'Active Residents',
      'subtitle': 'Student roster, room allocations, admission date, and guardians',
      'icon': Icons.people_alt_rounded,
      'color': const Color(0xFF0D9488),
    },
    {
      'id': 'fee_defaulters',
      'title': 'Fee Defaulters',
      'subtitle': 'Overdue hostel fee invoices, balance dues, and aging analysis',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFFDC2626),
    },
    {
      'id': 'movement',
      'title': 'Leave & Movements',
      'subtitle': 'Gate passes, outing register, checkout logs, and returns',
      'icon': Icons.departure_board_rounded,
      'color': const Color(0xFFD97706),
    },
    {
      'id': 'complaints',
      'title': 'Complaints Ledger',
      'subtitle': 'Maintenance tickets, resolution timeline, and staff assignees',
      'icon': Icons.build_circle_rounded,
      'color': const Color(0xFF7C3AED),
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(hostelProvider);
      if (state.reportsData.isEmpty || state.reportsData['records'] == null) {
        ref.read(hostelProvider.notifier).loadReportsData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
      _sortColumnKey = '';
      _sortAscending = true;
      _sortColumnIndex = null;
    });
  }

  void _onSort(String columnKey, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnKey = columnKey;
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> list) {
    if (_sortColumnKey.isEmpty) return list;
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final aVal = a[_sortColumnKey];
      final bVal = b[_sortColumnKey];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return _sortAscending ? -1 : 1;
      if (bVal == null) return _sortAscending ? 1 : -1;

      int cmp;
      if (aVal is num && bVal is num) {
        cmp = aVal.compareTo(bVal);
      } else {
        final aNum = num.tryParse(aVal.toString());
        final bNum = num.tryParse(bVal.toString());
        if (aNum != null && bNum != null) {
          cmp = aNum.compareTo(bNum);
        } else {
          cmp = aVal.toString().toLowerCase().compareTo(bVal.toString().toLowerCase());
        }
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentReportType = state.selectedReportType.isEmpty ? 'occupancy' : state.selectedReportType;
    final records = (state.reportsData['records'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Client-side quick filter
    final filteredRecords = _filterQuery.isEmpty
        ? records
        : records.where((row) {
            return row.values.any((val) =>
                val != null &&
                val.toString().toLowerCase().contains(_filterQuery.toLowerCase()));
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          _buildHeaderBar(context, state, notifier, isDark, state.isReportsLoading, filteredRecords),
          const SizedBox(height: 20),

          // Report Category Selection Cards
          _buildCategoryCards(currentReportType, notifier, isDark),
          const SizedBox(height: 20),

          // Session Turnover & Capacity Forecasting Intelligence Card
          const HostelTurnoverForecastCard(),
          const SizedBox(height: 20),

          // Filter Toolbar (Date range picker, search bar, clear filters)
          _buildFilterToolbar(context, state, notifier, isDark),
          const SizedBox(height: 16),

          // Results Overview & Data Table
          _buildResultsCard(
            context,
            currentReportType,
            filteredRecords,
            records.length,
            state.isReportsLoading,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
    bool isLoading,
    List<Map<String, dynamic>> filteredRecords,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final isMobile = constraints.maxWidth < 500;

        final titleSection = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hostel Reports & Analytical Exports',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Generate, filter, and export comprehensive operational, financial, and resident reports',
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isNarrow ? WrapAlignment.start : WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading ? null : () => notifier.loadReportsData(),
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () => notifier.exportReportCsv(customRecords: filteredRecords),
              icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
              label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final activeCat = _reportCategories.firstWhere(
                  (c) => c['id'] == state.selectedReportType,
                  orElse: () => _reportCategories.first,
                );
                final activeCols = _getColumnsForType(state.selectedReportType, filteredRecords);
                showDialog(
                  context: context,
                  builder: (_) => HostelReportPrintPreviewDialog(
                    reportTitle: activeCat['title'] as String,
                    academicYear: state.selectedAcademicYear,
                    columns: activeCols,
                    records: filteredRecords,
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
              label: const Text('Print Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );

        return Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleSection,
                    const SizedBox(height: 14),
                    actionButtons,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleSection),
                    const SizedBox(width: 14),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  List<String> _getColumnsForType(String type, List<Map<String, dynamic>> records) {
    switch (type) {
      case 'occupancy':
        return ['Building', 'Floor', 'Room No', 'Type', 'Capacity', 'Occupied', 'Vacant', 'Status', 'Monthly Fee', 'Restriction'];
      case 'residents':
        return ['Roll No', 'Student Name', 'Class', 'Building', 'Room No', 'Bed', 'Admission Date', 'Fee Status', 'Resident Status', 'Guardian Phone'];
      case 'fee_defaulters':
        return ['Roll No', 'Student Name', 'Building & Room', 'Invoice #', 'Billed (₹)', 'Paid (₹)', 'Pending Due (₹)', 'Due Date', 'Overdue Days', 'Status'];
      case 'movement':
        return ['Gate Pass #', 'Student Name', 'Building & Room', 'Type', 'Subtype', 'Purpose', 'Destination', 'Departure', 'Expected Return', 'Status'];
      case 'complaints':
        return ['Ticket #', 'Title', 'Category', 'Priority', 'Status', 'Room No', 'Student Name', 'Assigned Staff', 'Lodged Date'];
      default:
        return records.isNotEmpty ? records.first.keys.take(10).toList() : [];
    }
  }

  Widget _buildCategoryCards(
    String currentType,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth >= 950) {
          cardWidth = (constraints.maxWidth - 64) / 5;
        } else if (constraints.maxWidth >= 540) {
          cardWidth = (constraints.maxWidth - 16) / 2;
        } else {
          cardWidth = constraints.maxWidth;
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _reportCategories.map((cat) {
            final isSelected = cat['id'] == currentType;
            final Color color = cat['color'] as Color;

            return InkWell(
              onTap: () {
                if (cat['id'] != currentType) {
                  notifier.setReportType(cat['id'] as String);
                  _resetPagination();
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: isDark ? 0.2 : 0.08)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(cat['icon'] as IconData, color: color, size: 20),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cat['title'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilterToolbar(
    BuildContext context,
    HostelState state,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final hasDateFilter = state.reportsStartDate != null || state.reportsEndDate != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final searchBox = TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _filterQuery = val;
              _currentPage = 1;
            });
          },
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search within report records...',
            hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
            suffixIcon: _filterQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _filterQuery = '';
                        _currentPage = 1;
                      });
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
        );

        final dateButton = OutlinedButton.icon(
          onPressed: () async {
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              initialDateRange: state.reportsStartDate != null && state.reportsEndDate != null
                  ? DateTimeRange(start: state.reportsStartDate!, end: state.reportsEndDate!)
                  : null,
            );
            if (range != null) {
              notifier.setReportDateRange(range.start, range.end);
              _resetPagination();
            }
          },
          icon: const Icon(Icons.date_range_rounded, size: 16),
          label: Text(
            hasDateFilter
                ? '${dateFormat.format(state.reportsStartDate!)} - ${dateFormat.format(state.reportsEndDate!)}'
                : 'Filter by Date Range',
            style: const TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        final dateClearButton = hasDateFilter
            ? IconButton(
                icon: const Icon(Icons.highlight_off_rounded, size: 20, color: Color(0xFFEF4444)),
                tooltip: 'Clear Date Filter',
                onPressed: () {
                  notifier.setReportDateRange(null, null);
                  _resetPagination();
                },
              )
            : null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchBox,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: dateButton),
                        if (dateClearButton != null) ...[
                          const SizedBox(width: 8),
                          dateClearButton,
                        ],
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 3, child: searchBox),
                    const SizedBox(width: 14),
                    dateButton,
                    if (dateClearButton != null) ...[
                      const SizedBox(width: 8),
                      dateClearButton,
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildResultsCard(
    BuildContext context,
    String reportType,
    List<Map<String, dynamic>> records,
    int totalCount,
    bool isLoading,
    bool isDark,
  ) {
    if (isLoading) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 14),
              Text('Generating report data from database...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (records.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.find_in_page_outlined, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              Text(
                'No records found for this report criteria',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try broadening your date filter or selecting a different report category.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    // Apply client-side column sort
    final sortedRecords = _applySort(records);

    // Apply client-side pagination
    final totalRecords = sortedRecords.length;
    final totalPages = (totalRecords / _pageSize).ceil().clamp(1, 999999);
    final currentPage = _currentPage.clamp(1, totalPages);
    final startIndex = totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final pageRecords = totalRecords == 0
        ? <Map<String, dynamic>>[]
        : sortedRecords.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subheader bar with row counts & sort indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Report Records (${records.length}${records.length != totalCount ? ' of $totalCount' : ''})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (_sortColumnKey.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sorted by: $_sortColumnKey (${_sortAscending ? 'ASC' : 'DESC'})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _sortColumnKey = '';
                                  _sortColumnIndex = null;
                                });
                              },
                              child: const Icon(Icons.close, size: 12, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Real-time DB Snapshot',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Responsive Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1000),
              child: _buildDynamicDataTable(reportType, pageRecords, isDark),
            ),
          ),

          const Divider(height: 1),

          // Pagination Footer Bar
          _buildPaginationFooter(
            context,
            totalRecords: totalRecords,
            totalPages: totalPages,
            currentPage: currentPage,
            startIndex: startIndex,
            endIndex: endIndex,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(
    BuildContext context, {
    required int totalRecords,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 850;

          final countInfo = Text(
            'Showing ${totalRecords == 0 ? 0 : startIndex + 1} to $endIndex of $totalRecords records',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          );

          final pageSizeSelector = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page: ',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [10, 25, 50, 100].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size'),
                      );
                    }).toList(),
                    onChanged: (newSize) {
                      if (newSize != null) {
                        setState(() {
                          _pageSize = newSize;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          );

          final pagerButtons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // First Page
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
              ),
              // Prev Page
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1
                    ? () => setState(() => _currentPage = currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 4),

              // Page chips
              ..._buildPageChips(currentPage, totalPages, isDark),

              const SizedBox(width: 4),
              // Next Page
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = currentPage + 1)
                    : null,
              ),
              // Last Page
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                countInfo,
                const SizedBox(height: 8),
                pageSizeSelector,
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: pagerButtons,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              countInfo,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pageSizeSelector,
                  const SizedBox(width: 16),
                  pagerButtons,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildPageChips(int currentPage, int totalPages, bool isDark) {
    final List<int> pages = [];
    final start = (currentPage - 2).clamp(1, totalPages);
    final end = (currentPage + 2).clamp(1, totalPages);

    for (int i = start; i <= end; i++) {
      pages.add(i);
    }

    return pages.map((p) {
      final isCurrent = p == currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: () => setState(() => _currentPage = p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                color: isCurrent
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDynamicDataTable(
    String reportType,
    List<Map<String, dynamic>> records,
    bool isDark,
  ) {
    switch (reportType) {
      case 'occupancy':
        return _buildOccupancyTable(records, isDark);
      case 'residents':
        return _buildResidentsTable(records, isDark);
      case 'fee_defaulters':
        return _buildFeeDefaultersTable(records, isDark);
      case 'movement':
        return _buildMovementTable(records, isDark);
      case 'complaints':
        return _buildComplaintsTable(records, isDark);
      default:
        return _buildGenericTable(records, isDark);
    }
  }

  Widget _buildOccupancyTable(List<Map<String, dynamic>> rows, bool isDark) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: [
        DataColumn(label: const Text('Building', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('building_name', idx, asc)),
        DataColumn(label: const Text('Floor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('floor_name', idx, asc)),
        DataColumn(label: const Text('Room No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_number', idx, asc)),
        DataColumn(label: const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_type', idx, asc)),
        DataColumn(label: const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('capacity', idx, asc)),
        DataColumn(label: const Text('Occupied', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('occupied_beds', idx, asc)),
        DataColumn(label: const Text('Vacant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('vacant_beds', idx, asc)),
        DataColumn(label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_status', idx, asc)),
        DataColumn(label: const Text('Monthly Fee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('monthly_fee', idx, asc)),
        DataColumn(label: const Text('Restriction', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('gender_restriction', idx, asc)),
      ],
      rows: rows.map((r) {
        final vacant = (r['vacant_beds'] as num?)?.toInt() ?? 0;
        final status = r['room_status']?.toString() ?? 'OPERATIONAL';

        return DataRow(cells: [
          DataCell(Text(r['building_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(r['floor_name']?.toString() ?? '-')),
          DataCell(Text(r['room_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
          DataCell(Text(r['room_type']?.toString() ?? '-')),
          DataCell(Text('${r['capacity'] ?? 0}')),
          DataCell(Text('${r['occupied_beds'] ?? 0}')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: vacant > 0 ? const Color(0xFF16A34A).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$vacant',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: vacant > 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                ),
              ),
            ),
          ),
          DataCell(_buildStatusBadge(status)),
          DataCell(Text('₹${NumberFormat('#,##,###').format(r['monthly_fee'] ?? 0)}')),
          DataCell(Text(r['gender_restriction']?.toString() ?? 'ANY')),
        ]);
      }).toList(),
    );
  }

  Widget _buildResidentsTable(List<Map<String, dynamic>> rows, bool isDark) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: [
        DataColumn(label: const Text('Roll No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('roll_no', idx, asc)),
        DataColumn(label: const Text('Student Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('student_name', idx, asc)),
        DataColumn(label: const Text('Class', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('class_name', idx, asc)),
        DataColumn(label: const Text('Building', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('building_name', idx, asc)),
        DataColumn(label: const Text('Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_number', idx, asc)),
        DataColumn(label: const Text('Bed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('bed_label', idx, asc)),
        DataColumn(label: const Text('Admission Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('admission_date', idx, asc)),
        DataColumn(label: const Text('Fee Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('fee_status', idx, asc)),
        DataColumn(label: const Text('Resident Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('resident_status', idx, asc)),
        DataColumn(label: const Text('Guardian Phone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('guardian_phone', idx, asc)),
      ],
      rows: rows.map((r) {
        return DataRow(cells: [
          DataCell(Text(r['roll_no']?.toString() ?? '-', style: const TextStyle(color: Color(0xFF64748B)))),
          DataCell(Text(r['student_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(r['class_name']?.toString() ?? '-')),
          DataCell(Text(r['building_name']?.toString() ?? '-')),
          DataCell(Text(r['room_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r['bed_label']?.toString() ?? '-')),
          DataCell(Text(r['admission_date']?.toString() ?? '-')),
          DataCell(_buildStatusBadge(r['fee_status']?.toString() ?? 'PAID')),
          DataCell(_buildStatusBadge(r['resident_status']?.toString() ?? 'CHECKED_IN')),
          DataCell(Text(r['guardian_phone']?.toString() ?? r['student_phone']?.toString() ?? '-')),
        ]);
      }).toList(),
    );
  }

  Widget _buildFeeDefaultersTable(List<Map<String, dynamic>> rows, bool isDark) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: [
        DataColumn(label: const Text('Roll No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('roll_no', idx, asc)),
        DataColumn(label: const Text('Student Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('student_name', idx, asc)),
        DataColumn(label: const Text('Building & Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_number', idx, asc)),
        DataColumn(label: const Text('Invoice #', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('invoice_number', idx, asc)),
        DataColumn(label: const Text('Billed (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('billed_amount', idx, asc)),
        DataColumn(label: const Text('Paid (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('paid_amount', idx, asc)),
        DataColumn(label: const Text('Pending Due (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('pending_due', idx, asc)),
        DataColumn(label: const Text('Due Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('due_date', idx, asc)),
        DataColumn(label: const Text('Overdue Days', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('overdue_days', idx, asc)),
        DataColumn(label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('payment_status', idx, asc)),
      ],
      rows: rows.map((r) {
        final overdueDays = (r['overdue_days'] as num?)?.toInt() ?? 0;
        final pendingDue = (r['pending_due'] as num?)?.toDouble() ?? 0.0;

        return DataRow(cells: [
          DataCell(Text(r['roll_no']?.toString() ?? '-', style: const TextStyle(color: Color(0xFF64748B)))),
          DataCell(Text(r['student_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text('${r['building_name'] ?? '-'} (${r['room_number'] ?? '-'})')),
          DataCell(Text(r['invoice_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
          DataCell(Text('₹${NumberFormat('#,##,###').format(r['billed_amount'] ?? 0)}')),
          DataCell(Text('₹${NumberFormat('#,##,###').format(r['paid_amount'] ?? 0)}')),
          DataCell(Text(
            '₹${NumberFormat('#,##,###').format(pendingDue)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
          )),
          DataCell(Text(r['due_date']?.toString() ?? '-')),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: overdueDays > 30 ? const Color(0xFFDC2626).withValues(alpha: 0.12) : const Color(0xFFD97706).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$overdueDays days',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: overdueDays > 30 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                ),
              ),
            ),
          ),
          DataCell(_buildStatusBadge(r['payment_status']?.toString() ?? 'PENDING')),
        ]);
      }).toList(),
    );
  }

  Widget _buildMovementTable(List<Map<String, dynamic>> rows, bool isDark) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: [
        DataColumn(label: const Text('Gate Pass #', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('gate_pass_code', idx, asc)),
        DataColumn(label: const Text('Student Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('student_name', idx, asc)),
        DataColumn(label: const Text('Building & Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_number', idx, asc)),
        DataColumn(label: const Text('Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('request_type', idx, asc)),
        DataColumn(label: const Text('Subtype', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('request_subtype', idx, asc)),
        DataColumn(label: const Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('purpose', idx, asc)),
        DataColumn(label: const Text('Destination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('destination', idx, asc)),
        DataColumn(label: const Text('Departure', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('departure_date', idx, asc)),
        DataColumn(label: const Text('Expected Return', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('expected_return', idx, asc)),
        DataColumn(label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('status', idx, asc)),
      ],
      rows: rows.map((r) {
        return DataRow(cells: [
          DataCell(Text(r['gate_pass_code']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
          DataCell(Text(r['student_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text('${r['building_name'] ?? '-'} (${r['room_number'] ?? '-'})')),
          DataCell(Text(r['request_type']?.toString() ?? '-')),
          DataCell(Text(r['request_subtype']?.toString() ?? '-')),
          DataCell(ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(r['purpose']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis),
          )),
          DataCell(Text(r['destination']?.toString() ?? '-')),
          DataCell(Text(r['departure_date'] != null ? r['departure_date'].toString().split('.').first : '-')),
          DataCell(Text(r['expected_return'] != null ? r['expected_return'].toString().split('.').first : '-')),
          DataCell(_buildStatusBadge(r['status']?.toString() ?? 'APPROVED')),
        ]);
      }).toList(),
    );
  }

  Widget _buildComplaintsTable(List<Map<String, dynamic>> rows, bool isDark) {
    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: [
        DataColumn(label: const Text('Ticket #', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('ticket_number', idx, asc)),
        DataColumn(label: const Text('Title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('title', idx, asc)),
        DataColumn(label: const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('category', idx, asc)),
        DataColumn(label: const Text('Priority', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('priority', idx, asc)),
        DataColumn(label: const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('status', idx, asc)),
        DataColumn(label: const Text('Room', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('room_number', idx, asc)),
        DataColumn(label: const Text('Resident', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('student_name', idx, asc)),
        DataColumn(label: const Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('assigned_staff', idx, asc)),
        DataColumn(label: const Text('Lodged Date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), onSort: (idx, asc) => _onSort('lodged_date', idx, asc)),
      ],
      rows: rows.map((r) {
        final priority = r['priority']?.toString() ?? 'MEDIUM';

        return DataRow(cells: [
          DataCell(Text(r['ticket_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)))),
          DataCell(ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(r['title']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          )),
          DataCell(Text(r['category']?.toString() ?? '-')),
          DataCell(_buildPriorityBadge(priority)),
          DataCell(_buildStatusBadge(r['status']?.toString() ?? 'OPEN')),
          DataCell(Text(r['room_number']?.toString() ?? '-')),
          DataCell(Text(r['student_name']?.toString() ?? '-')),
          DataCell(Text(r['assigned_staff']?.toString() ?? 'Unassigned')),
          DataCell(Text(r['lodged_date'] != null ? r['lodged_date'].toString().split('.').first : '-')),
        ]);
      }).toList(),
    );
  }

  Widget _buildGenericTable(List<Map<String, dynamic>> rows, bool isDark) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final keys = rows.first.keys.toList();

    return DataTable(
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      columns: keys.asMap().entries.map((e) {
        return DataColumn(
          label: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          onSort: (idx, asc) => _onSort(e.value, idx, asc),
        );
      }).toList(),
      rows: rows.map((r) {
        return DataRow(
          cells: keys.map((k) => DataCell(Text(r[k]?.toString() ?? '-'))).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    final s = status.toUpperCase();
    if (s.contains('PAID') || s.contains('OPERATIONAL') || s.contains('RESOLVED') || s.contains('CHECKED_IN')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (s.contains('PENDING') || s.contains('OVERDUE') || s.contains('EXITED') || s.contains('IN_PROGRESS')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    } else if (s.contains('UNPAID') || s.contains('MAINTENANCE') || s.contains('REJECTED') || s.contains('HIGH')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    switch (priority.toUpperCase()) {
      case 'URGENT':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case 'HIGH':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        break;
      case 'MEDIUM':
        bg = const Color(0xFFFEF9C3);
        fg = const Color(0xFFA16207);
        break;
      case 'LOW':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        priority,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
