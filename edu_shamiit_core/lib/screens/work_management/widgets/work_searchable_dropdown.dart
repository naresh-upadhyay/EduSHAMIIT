import 'package:flutter/material.dart';

/// Premium, high-performance searchable dropdown component designed for
/// enterprise Work Management filters across all tabs.
///
/// Features:
/// - Inline live type-to-search with autofocus and clear button.
/// - Strict alphabetical sorting with "All" / "All ..." pinned at the top.
/// - Smart screen-boundary positioning (automatically flips above or shifts if near edge).
/// - Active selection checkmark and highlighted search matches.
/// - Keyboard navigation (Enter to select first result, Escape to close).
/// - Dark/Light mode theme responsive.
class WorkSearchableDropdown extends StatefulWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String>? onChanged;
  final String? label;
  final String? hint;
  final IconData? icon;
  final double? width;
  final double? dropdownWidth;
  final double maxDropdownHeight;
  final bool compact;
  final bool showClearButton;
  final Map<String, IconData>? itemIcons;
  final Map<String, Color>? itemColors;

  const WorkSearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.icon,
    this.width,
    this.dropdownWidth,
    this.maxDropdownHeight = 340.0,
    this.compact = true,
    this.showClearButton = false,
    this.itemIcons,
    this.itemColors,
  });

  /// Sorts a list of dropdown options so that any "All" option remains pinned at index 0,
  /// while all remaining items are sorted alphabetically in a case-insensitive manner.
  static List<String> sortOptions(Iterable<String> rawItems) {
    final unique = <String>{};
    for (final item in rawItems) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty) {
        unique.add(trimmed);
      }
    }

    String? allItem;
    final others = <String>[];

    for (final item in unique) {
      final lower = item.toLowerCase();
      if (lower == 'all' || lower.startsWith('all ')) {
        // Prefer exact 'All' if available, otherwise keep the first 'All ...'
        if (allItem == null || lower == 'all') {
          if (allItem != null && allItem.toLowerCase() != 'all') {
            others.add(allItem);
          }
          allItem = item;
          continue;
        }
      }
      others.add(item);
    }

    others.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (allItem != null) {
      return [allItem, ...others];
    }
    return others;
  }

  @override
  State<WorkSearchableDropdown> createState() => _WorkSearchableDropdownState();
}

class _WorkSearchableDropdownState extends State<WorkSearchableDropdown> {
  final LayerLink _layerLink = LayerLink();

  void _showDropdownMenu() {
    if (widget.onChanged == null || widget.items.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final sortedItems = WorkSearchableDropdown.sortOptions(widget.items);
    final menuWidth = widget.dropdownWidth ?? (widget.width != null ? widget.width!.clamp(240.0, 360.0) : 260.0);

    // Calculate vertical position
    final spaceBelow = screenSize.height - (targetOffset.dy + targetSize.height);
    final spaceAbove = targetOffset.dy;
    final openUpwards = spaceBelow < widget.maxDropdownHeight + 20 && spaceAbove > spaceBelow;

    // Calculate horizontal position
    double left = targetOffset.dx;
    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }
    if (left < 12) left = 12;

    double top;
    double maxHeight;
    if (openUpwards) {
      maxHeight = (spaceAbove - 16).clamp(120.0, widget.maxDropdownHeight);
      top = targetOffset.dy - maxHeight - 4;
    } else {
      maxHeight = (spaceBelow - 16).clamp(120.0, widget.maxDropdownHeight);
      top = targetOffset.dy + targetSize.height + 4;
    }

    showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) {
        return Stack(
          children: [
            // Barrier dismisser
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
            // Floating Dropdown Menu
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _SearchableDropdownMenuContent(
                label: widget.label ?? 'Option',
                currentValue: widget.value,
                items: sortedItems,
                maxHeight: maxHeight,
                itemIcons: widget.itemIcons,
                itemColors: widget.itemColors,
                onSelected: (val) {
                  Navigator.of(dialogCtx).pop(val);
                },
              ),
            ),
          ],
        );
      },
    ).then((selected) {
      if (selected != null && selected != widget.value) {
        widget.onChanged?.call(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = widget.value?.isNotEmpty == true
        ? widget.value!
        : (widget.hint ?? 'All');
    final isNonDefault = displayValue.toLowerCase() != 'all' && !displayValue.toLowerCase().startsWith('all ');

    final borderColor = isNonDefault
        ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    final bgColor = isNonDefault
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF0F172A) : Colors.white);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: widget.label != null ? '${widget.label}: $displayValue' : displayValue,
        waitDuration: const Duration(milliseconds: 700),
        child: InkWell(
          onTap: widget.onChanged != null ? _showDropdownMenu : null,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          child: Container(
            width: widget.width,
            constraints: const BoxConstraints(minHeight: 34),
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 12,
              vertical: widget.compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: widget.compact ? 14 : 16,
                    color: isNonDefault ? const Color(0xFF3B82F6) : labelColor,
                  ),
                  const SizedBox(width: 6),
                ],
                if (widget.label != null && widget.label!.isNotEmpty) ...[
                  Text(
                    '${widget.label}: ',
                    style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.compact ? 12 : 13,
                      fontWeight: isNonDefault ? FontWeight.w600 : FontWeight.normal,
                      color: isNonDefault ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)) : textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: widget.compact ? 16 : 18,
                  color: labelColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchableDropdownMenuContent extends StatefulWidget {
  final String label;
  final String? currentValue;
  final List<String> items;
  final double maxHeight;
  final Map<String, IconData>? itemIcons;
  final Map<String, Color>? itemColors;
  final ValueChanged<String> onSelected;

  const _SearchableDropdownMenuContent({
    required this.label,
    required this.currentValue,
    required this.items,
    required this.maxHeight,
    required this.onSelected,
    this.itemIcons,
    this.itemColors,
  });

  @override
  State<_SearchableDropdownMenuContent> createState() => _SearchableDropdownMenuContentState();
}

class _SearchableDropdownMenuContentState extends State<_SearchableDropdownMenuContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items.where((item) => item.toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;

    final bgCardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: bgCardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(fontSize: 12, color: textColor),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (val) {
                          if (filtered.isNotEmpty) {
                            widget.onSelected(filtered.first);
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded, size: 16, color: secondaryTextColor),
                          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  splashRadius: 12,
                                  color: secondaryTextColor,
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          hintText: 'Search ${widget.label.toLowerCase()}...',
                          hintStyle: TextStyle(fontSize: 12, color: secondaryTextColor),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata summary (e.g. "Showing 27 items")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} of ${widget.items.length} ${widget.label.toLowerCase()}s',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: secondaryTextColor),
                  ),
                  if (widget.currentValue != null &&
                      widget.currentValue!.toLowerCase() != 'all' &&
                      !widget.currentValue!.toLowerCase().startsWith('all '))
                    InkWell(
                      onTap: () {
                        final allOption = widget.items.firstWhere(
                          (item) => item.toLowerCase() == 'all' || item.toLowerCase().startsWith('all '),
                          orElse: () => 'All',
                        );
                        widget.onSelected(allOption);
                      },
                      child: Text(
                        'Reset to All',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Items List
            Flexible(
              child: filtered.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 24, color: secondaryTextColor),
                          const SizedBox(height: 6),
                          Text(
                            'No matches found',
                            style: TextStyle(fontSize: 12, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.toLowerCase() == (widget.currentValue ?? '').toLowerCase();
                        final icon = widget.itemIcons?[item];
                        final color = widget.itemColors?[item];

                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                if (color != null) ...[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else if (icon != null) ...[
                                  Icon(icon, size: 14, color: isSelected ? const Color(0xFF3B82F6) : secondaryTextColor),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: _highlightMatch(
                                    item,
                                    _searchQuery,
                                    textColor: isSelected
                                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                        : textColor,
                                    highlightColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                    isSelected: isSelected,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highlightMatch(
    String text,
    String query, {
    required Color textColor,
    required Color highlightColor,
    required bool isSelected,
  }) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final matchIndex = lowerText.indexOf(query);
    if (matchIndex < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
        ),
      );
    }

    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before, style: TextStyle(color: textColor, fontSize: 12)),
          TextSpan(
            text: match,
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              backgroundColor: highlightColor.withValues(alpha: 0.12),
            ),
          ),
          TextSpan(text: after, style: TextStyle(color: textColor, fontSize: 12)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
