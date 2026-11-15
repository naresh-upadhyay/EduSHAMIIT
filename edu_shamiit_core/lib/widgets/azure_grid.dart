import 'dart:math';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:google_fonts/google_fonts.dart';

/// Column definition for the [AzureGrid] table view.
class AzureGridColumn<T> {
  final String label;
  final Widget Function(T item) cellBuilder;
  final double width;
  final int Function(T a, T b)? compare;

  AzureGridColumn({
    required this.label,
    required this.cellBuilder,
    this.width = 150.0,
    this.compare,
  });
}

/// Filter definition for the [AzureGrid] command bar.
class AzureGridFilter<T> {
  final String label;
  final List<String> options;
  final bool Function(T item, String selectedOption) filterFn;

  AzureGridFilter({
    required this.label,
    required this.options,
    required this.filterFn,
  });
}

/// A highly dense, premium responsive data grid modeled after the Azure Cloud Platform UI.
///
/// Features:
/// - Dense tabular layout for desktop and tablet screens.
/// - Adaptive card-based layout for mobile screens.
/// - Command bar with search, multi-filters, bulk actions, and count tags.
/// - Multiselect checkboxes.
/// - Dynamic interactive column sorting.
/// - Azure-style pagination controls with configurable page sizes.
/// - Proportional column stretching when columns fit within the viewport.
/// - Custom horizontal and vertical scrollbars for smooth desktop/web navigation.
class AzureGrid<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final List<AzureGridColumn<T>> columns;
  final Widget Function(BuildContext context, T item) mobileCardBuilder;
  final List<Widget> Function(BuildContext context, List<T> selectedItems)?
      bulkActions;
  final List<AzureGridFilter<T>>? filters;
  final String Function(T item)? searchMatcher;
  final int defaultPageSize;
  final bool enableSelection;
  final List<Widget>? extraCommandActions;
  final List<Widget>? extraCommandFilters;
  final Widget? subHeader;
  final VoidCallback? onRefresh;
  final bool disableVerticalScroll;
  final bool loading;
  final void Function(String label, String value)? onFilterChanged;

  const AzureGrid({
    super.key,
    required this.title,
    required this.items,
    required this.columns,
    required this.mobileCardBuilder,
    this.bulkActions,
    this.filters,
    this.searchMatcher,
    this.defaultPageSize = 10,
    this.enableSelection = false,
    this.extraCommandActions,
    this.extraCommandFilters,
    this.subHeader,
    this.onRefresh,
    this.disableVerticalScroll = false,
    this.loading = false,
    this.onFilterChanged,
  });

  @override
  State<AzureGrid<T>> createState() => _AzureGridState<T>();
}

class _AzureGridState<T> extends State<AzureGrid<T>> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  String _searchQuery = '';
  final Map<String, String> _activeFilters = {};
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentPage = 0;
  late int _pageSize;
  final Set<T> _selectedItems = {};
  T? _hoveredItem;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  // Helper: Retrieve filtered and sorted items list
  List<T> get _processedItems {
    List<T> results = List.from(widget.items);

    // 1. Apply Search
    if (_searchQuery.isNotEmpty && widget.searchMatcher != null) {
      final query = _searchQuery.toLowerCase();
      results = results.where((item) {
        return widget.searchMatcher!(item).toLowerCase().contains(query);
      }).toList();
    }

    // 2. Apply Custom Filters
    if (widget.filters != null) {
      for (final filter in widget.filters!) {
        final selectedVal = _activeFilters[filter.label];
        if (selectedVal != null && selectedVal != 'All') {
          results = results
              .where((item) => filter.filterFn(item, selectedVal))
              .toList();
        }
      }
    }

    // 3. Apply Sorting
    if (_sortColumnIndex != null && _sortColumnIndex! < widget.columns.length) {
      final col = widget.columns[_sortColumnIndex!];
      if (col.compare != null) {
        results.sort((a, b) {
          final cmp = col.compare!(a, b);
          return _sortAscending ? cmp : -cmp;
        });
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final processed = _processedItems;
    final isMobile = Responsive.isMobile(context);

    // Compute paginated subset
    final totalItems = processed.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    } else if (totalPages == 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalItems);
    final pagedItems =
        totalItems > 0 ? processed.sublist(startIndex, endIndex) : <T>[];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E2E38) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Command Bar (Header + Search + Filters + Actions)
          _buildCommandBar(context, isMobile),

          if (widget.loading)
            const LinearProgressIndicator(
                minHeight: 2, backgroundColor: Colors.transparent),

          const Divider(height: 1, thickness: 1),

          // Sub-header (e.g. stats row)
          if (widget.subHeader != null) ...[
            widget.subHeader!,
            const Divider(height: 1, thickness: 1),
          ],

          // 2. Content (Table or Mobile Cards list)
          widget.disableVerticalScroll
              ? (totalItems == 0
                  ? _buildEmptyState(isDark)
                  : isMobile
                      ? _buildMobileListView(pagedItems)
                      : _buildDesktopGrid(pagedItems, context, isDark))
              : Expanded(
                  child: totalItems == 0
                      ? _buildEmptyState(isDark)
                      : isMobile
                          ? _buildMobileListView(pagedItems)
                          : _buildDesktopGrid(pagedItems, context, isDark),
                ),

          const Divider(height: 1, thickness: 1),

          // 3. Pagination Controls (Footer)
          _buildPaginationFooter(
              totalItems, startIndex, endIndex, totalPages, isDark),
        ],
      ),
    );
  }

  // ─── COMMAND BAR BUILDER ──────────────────────────────────────────
  Widget _buildCommandBar(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final commandBg =
        isDark ? const Color(0xFF18181F) : const Color(0xFFF8F9FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: commandBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Title & Extra Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (_selectedItems.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_selectedItems.length} selected',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (widget.onRefresh != null)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Refresh',
                      onPressed: () {
                        setState(() {
                          _selectedItems.clear();
                        });
                        widget.onRefresh!();
                      },
                    ),
                  if (widget.extraCommandActions != null)
                    ...widget.extraCommandActions!,
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Search, Filters & Bulk Actions
          if (isMobile) ...[
            if (widget.searchMatcher != null) ...[
              SizedBox(
                width: double.infinity,
                height: 32,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 0;
                    });
                  },
                  style: GoogleFonts.dmSans(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _currentPage = 0;
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF262633) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (widget.extraCommandFilters != null) ...[
                    ...widget.extraCommandFilters!.map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: f,
                        )),
                  ],
                  if (widget.filters != null) ...[
                    ...widget.filters!.map((filter) {
                      final currentVal = _activeFilters[filter.label] ?? 'All';
                      return Container(
                        height: 32,
                        margin: const EdgeInsets.only(right: 8.0),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262633) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: currentVal != 'All'
                                ? theme.colorScheme.primary
                                : (isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentVal,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: currentVal != 'All'
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white : Colors.black87),
                              fontWeight: currentVal != 'All' ? FontWeight.bold : FontWeight.normal,
                            ),
                            dropdownColor: isDark ? const Color(0xFF262633) : Colors.white,
                            items: ['All', ...filter.options].map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt,
                                child: Text(opt == 'All' ? '${filter.label}: All' : opt),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _activeFilters[filter.label] = val;
                                  _currentPage = 0;
                                });
                                if (widget.onFilterChanged != null) {
                                  widget.onFilterChanged!(filter.label, val);
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                  if (_selectedItems.isNotEmpty && widget.bulkActions != null) ...[
                    ...widget.bulkActions!(context, _selectedItems.toList()).map((action) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            height: 32,
                            child: action,
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.extraCommandFilters != null) ...widget.extraCommandFilters!,
                if (widget.searchMatcher != null)
                  SizedBox(
                    width: 240,
                    height: 32,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 0;
                        });
                      },
                      style: GoogleFonts.dmSans(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _currentPage = 0;
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF262633) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                if (widget.filters != null)
                  ...widget.filters!.map((filter) {
                    final currentVal = _activeFilters[filter.label] ?? 'All';
                    return Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262633) : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: currentVal != 'All'
                              ? theme.colorScheme.primary
                              : (isDark ? const Color(0xFF3A3A4A) : Colors.grey.shade300),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentVal,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: currentVal != 'All'
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.white : Colors.black87),
                            fontWeight: currentVal != 'All' ? FontWeight.bold : FontWeight.normal,
                          ),
                          dropdownColor: isDark ? const Color(0xFF262633) : Colors.white,
                          items: ['All', ...filter.options].map((opt) {
                            return DropdownMenuItem<String>(
                              value: opt,
                              child: Text(opt == 'All' ? '${filter.label}: All' : opt),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _activeFilters[filter.label] = val;
                                _currentPage = 0;
                              });
                              if (widget.onFilterChanged != null) {
                                widget.onFilterChanged!(filter.label, val);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  }),
                if (_selectedItems.isNotEmpty && widget.bulkActions != null)
                  ...widget.bulkActions!(context, _selectedItems.toList()).map((action) {
                    return SizedBox(
                      height: 32,
                      child: action,
                    );
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── DESKTOP DATA TABLE BUILDER ───────────────────────────────────
  Widget _buildDesktopGrid(
      List<T> pagedItems, BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;

        // Calculate total column width
        double selectionWidth = widget.enableSelection ? 50.0 : 0.0;
        double specifiedColumnsWidth =
            widget.columns.fold(0.0, (sum, col) => sum + col.width);
        double totalMinWidth = specifiedColumnsWidth + selectionWidth;

        // Proportional resizing if totalMinWidth is less than the viewport width
        final double scale = totalMinWidth < viewportWidth
            ? (viewportWidth / totalMinWidth)
            : 1.0;
        final double finalSelectionWidth = selectionWidth * scale;

        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: max(viewportWidth, totalMinWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Table Header
                    _buildTableHeader(
                        pagedItems, finalSelectionWidth, scale, isDark),

                    const Divider(height: 1, thickness: 1),

                    // Table Body
                    widget.disableVerticalScroll
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(pagedItems.length, (index) {
                              final item = pagedItems[index];
                              return _buildTableRow(
                                item: item,
                                index: index,
                                selectionWidth: finalSelectionWidth,
                                scale: scale,
                                isDark: isDark,
                              );
                            }),
                          )
                        : Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: pagedItems.length,
                                itemBuilder: (context, index) {
                                  final item = pagedItems[index];
                                  return _buildTableRow(
                                    item: item,
                                    index: index,
                                    selectionWidth: finalSelectionWidth,
                                    scale: scale,
                                    isDark: isDark,
                                  );
                                },
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

  Widget _buildTableHeader(
      List<T> pagedItems, double selectionWidth, double scale, bool isDark) {
    final headerBg = isDark ? const Color(0xFF22222E) : Colors.grey.shade50;
    final headerTextTheme = GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
    );

    final isAllSelected = pagedItems.isNotEmpty &&
        pagedItems.every((item) => _selectedItems.contains(item));

    return Container(
      color: headerBg,
      height: 40,
      child: Row(
        children: [
          // Select All Checkbox
          if (widget.enableSelection)
            SizedBox(
              width: selectionWidth,
              child: Checkbox(
                value: isAllSelected,
                tristate: pagedItems.isNotEmpty &&
                    pagedItems.any((item) => _selectedItems.contains(item)) &&
                    !isAllSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedItems.addAll(pagedItems);
                    } else {
                      for (final item in pagedItems) {
                        _selectedItems.remove(item);
                      }
                    }
                  });
                },
              ),
            ),

          // Header Cells
          ...widget.columns.asMap().entries.map((entry) {
            final idx = entry.key;
            final col = entry.value;
            final colWidth = col.width * scale;

            final isSorted = _sortColumnIndex == idx;

            Widget headerCell = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    col.label,
                    style: headerTextTheme,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (col.compare != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isSorted
                        ? (_sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward)
                        : Icons.swap_vert,
                    size: 14,
                    color: isSorted
                        ? Theme.of(context).colorScheme.primary
                        : (isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade400),
                  ),
                ],
              ],
            );

            if (col.compare != null) {
              headerCell = InkWell(
                onTap: () {
                  setState(() {
                    if (_sortColumnIndex == idx) {
                      if (_sortAscending) {
                        _sortAscending = false;
                      } else {
                        _sortColumnIndex = null; // reset sort
                      }
                    } else {
                      _sortColumnIndex = idx;
                      _sortAscending = true;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: headerCell,
                ),
              );
            }

            return SizedBox(
              width: colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: headerCell,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required T item,
    required int index,
    required double selectionWidth,
    required double scale,
    required bool isDark,
  }) {
    final isSelected = _selectedItems.contains(item);
    final isHovered = _hoveredItem == item;

    Color rowColor = Colors.transparent;
    if (isSelected) {
      rowColor = isDark
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06);
    } else if (isHovered) {
      rowColor = isDark ? const Color(0xFF252530) : Colors.grey.shade100;
    } else if (index % 2 != 0) {
      rowColor = isDark ? const Color(0xFF1B1B22) : const Color(0xFFFAFAFC);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredItem = item),
      onExit: (_) => setState(() => _hoveredItem = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.enableSelection) {
            setState(() {
              if (isSelected) {
                _selectedItems.remove(item);
              } else {
                _selectedItems.add(item);
              }
            });
          }
        },
        child: Container(
          color: rowColor,
          height: 38, // dense height
          child: Row(
            children: [
              // Row Checkbox
              if (widget.enableSelection)
                SizedBox(
                  width: selectionWidth,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItems.add(item);
                        } else {
                          _selectedItems.remove(item);
                        }
                      });
                    },
                  ),
                ),

              // Data Cells
              ...widget.columns.map((col) {
                final colWidth = col.width * scale;
                return SizedBox(
                  width: colWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DefaultTextStyle(
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade200 : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        child: col.cellBuilder(item),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MOBILE VIEW BUILDER ──────────────────────────────────────────
  Widget _buildMobileListView(List<T> pagedItems) {
    if (widget.disableVerticalScroll) {
      return Padding(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pagedItems.length, (idx) {
            final item = pagedItems[idx];
            final isSelected = _selectedItems.contains(item);

            Widget mobileCard = widget.mobileCardBuilder(context, item);

            if (widget.enableSelection) {
              mobileCard = Stack(
                children: [
                  mobileCard,
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Transform.scale(
                      scale: 0.8,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedItems.add(item);
                            } else {
                              _selectedItems.remove(item);
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: idx == pagedItems.length - 1 ? 0 : 8),
              child: GestureDetector(
                onLongPress: () {
                  if (widget.enableSelection) {
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(item);
                      } else {
                        _selectedItems.add(item);
                      }
                    });
                  }
                },
                child: mobileCard,
              ),
            );
          }),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 12),
      itemCount: pagedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final item = pagedItems[idx];
        final isSelected = _selectedItems.contains(item);

        Widget mobileCard = widget.mobileCardBuilder(context, item);

        if (widget.enableSelection) {
          mobileCard = Stack(
            children: [
              mobileCard,
              Positioned(
                top: 4,
                left: 4,
                child: Transform.scale(
                  scale: 0.8,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItems.add(item);
                        } else {
                          _selectedItems.remove(item);
                        }
                      });
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return GestureDetector(
          onLongPress: () {
            if (widget.enableSelection) {
              setState(() {
                if (isSelected) {
                  _selectedItems.remove(item);
                } else {
                  _selectedItems.add(item);
                }
              });
            }
          },
          child: mobileCard,
        );
      },
    );
  }

  // ─── FOOTER & PAGINATION BUILDER ──────────────────────────────────
  Widget _buildPaginationFooter(int totalItems, int startIndex, int endIndex,
      int totalPages, bool isDark) {
    final footerBg = isDark ? const Color(0xFF18181F) : const Color(0xFFF8F9FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: footerBg,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Items Per Page Dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Items per page:',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: DropdownButton<int>(
                  value: _pageSize,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  dropdownColor:
                      isDark ? const Color(0xFF262633) : Colors.white,
                  underline: const SizedBox(),
                  items: [5, 10, 25, 50, 100].map((size) {
                    return DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 0; // reset
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          // Showing entries info
          Text(
            totalItems == 0
                ? 'Showing 0-0 of 0 items'
                : 'Showing ${startIndex + 1}-$endIndex of $totalItems items',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),

          // Pagination buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 18),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Text(
                'Page ${_currentPage + 1} of ${max(1, totalPages)}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 18),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_off_outlined,
            size: 40,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching records found',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
