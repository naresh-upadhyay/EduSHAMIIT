import 'package:flutter/material.dart';
import 'dropdown_models.dart';

/// Enterprise-grade searchable dropdown for toolbars, filters, table headers,
/// and contextual selection across the EduSHAMIIT platform.
class AppSearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final String Function(T item)? itemLabel;
  final String? Function(T item)? itemSubtitle;
  final IconData? Function(T item)? itemIcon;
  final Color? Function(T item)? itemIconColor;
  final String? label;
  final String? hint;
  final dynamic icon;
  final double? width;
  final double? dropdownWidth;
  final double maxDropdownHeight;
  final bool compact;
  final bool showClearButton;
  final bool pinAllOption;
  final bool allowClear;
  final bool isDense;
  final bool isExpanded;
  final Color? dropdownColor;
  final TextStyle? style;
  final Map<T, IconData>? itemIcons;
  final Map<T, Color>? itemColors;
  final bool? borderless;
  final Widget? underline;
  final Color? iconEnabledColor;
  final Color? iconDisabledColor;
  final double? iconSize;
  final DropdownButtonBuilder? selectedItemBuilder;
  final AlignmentGeometry? alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final int? elevation;
  final double? itemHeight;
  final FocusNode? focusNode;
  final bool autofocus;
  final double? menuMaxHeight;
  final bool? enableFeedback;
  final VoidCallback? onTap;
  final dynamic disabledHint;

  const AppSearchableDropdown({
    super.key,
    this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.itemIconColor,
    this.label,
    this.hint,
    this.icon,
    this.width,
    this.dropdownWidth,
    this.maxDropdownHeight = 340.0,
    this.compact = true,
    this.showClearButton = false,
    this.pinAllOption = true,
    this.allowClear = false,
    this.isDense = false,
    this.isExpanded = true,
    this.dropdownColor,
    this.style,
    this.itemIcons,
    this.itemColors,
    this.borderless,
    this.underline,
    this.iconEnabledColor,
    this.iconDisabledColor,
    this.iconSize,
    this.selectedItemBuilder,
    this.alignment,
    this.borderRadius,
    this.padding,
    this.elevation,
    this.itemHeight,
    this.focusNode,
    this.autofocus = false,
    this.menuMaxHeight,
    this.enableFeedback,
    this.onTap,
    this.disabledHint,
  });

  /// Drop-in adapter factory constructor that accepts existing `List<DropdownMenuItem<T>>`.
  factory AppSearchableDropdown.fromMenuItems({
    Key? key,
    T? value,
    required List<DropdownMenuItem<T>>? items,
    required ValueChanged<T?>? onChanged,
    String? label,
    dynamic hint,
    dynamic icon,
    double? width,
    double? dropdownWidth,
    double maxDropdownHeight = 340.0,
    bool compact = true,
    bool showClearButton = false,
    bool pinAllOption = false,
    bool allowClear = false,
    bool isDense = false,
    bool isExpanded = true,
    Color? dropdownColor,
    TextStyle? style,
    bool? borderless,
    Widget? underline,
    Color? iconEnabledColor,
    Color? iconDisabledColor,
    double? iconSize,
    DropdownButtonBuilder? selectedItemBuilder,
    AlignmentGeometry? alignment,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    int? elevation,
    double? itemHeight,
    FocusNode? focusNode,
    bool autofocus = false,
    double? menuMaxHeight,
    bool? enableFeedback,
    VoidCallback? onTap,
    dynamic disabledHint,
  }) {
    final Map<T?, String> labelCache = {};
    final List<T> valuesList = [];

    if (items != null) {
      for (final item in items) {
        if (item.value != null) {
          valuesList.add(item.value as T);
        }
        labelCache[item.value] = _extractTextFromWidget(item.child);
      }
    }

    String? extractedHint;
    if (hint is String) {
      extractedHint = hint;
    } else if (hint is Widget) {
      extractedHint = _extractTextFromWidget(hint);
    }

    return AppSearchableDropdown<T>(
      key: key,
      value: value,
      items: valuesList,
      itemLabel: (it) => (it == null ? '' : (labelCache[it] ?? it.toString())),
      onChanged: onChanged,
      label: label,
      hint: extractedHint,
      icon: icon,
      width: width,
      dropdownWidth: dropdownWidth,
      maxDropdownHeight: menuMaxHeight ?? maxDropdownHeight,
      compact: compact,
      showClearButton: showClearButton,
      pinAllOption: pinAllOption,
      allowClear: allowClear,
      isDense: isDense,
      isExpanded: isExpanded,
      dropdownColor: dropdownColor,
      style: style,
      borderless: borderless,
      underline: underline,
      iconEnabledColor: iconEnabledColor,
      iconDisabledColor: iconDisabledColor,
      iconSize: iconSize,
      selectedItemBuilder: selectedItemBuilder,
      alignment: alignment,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      itemHeight: itemHeight,
      focusNode: focusNode,
      autofocus: autofocus,
      menuMaxHeight: menuMaxHeight,
      enableFeedback: enableFeedback,
      onTap: onTap,
      disabledHint: disabledHint,
    );
  }

  static String _extractTextFromWidget(Widget widget) {
    if (widget is Text) {
      return widget.data ?? '';
    }
    if (widget is Row) {
      final buffer = StringBuffer();
      for (final child in widget.children) {
        if (child is Text) {
          buffer.write(child.data ?? '');
        } else if (child is Flexible && child.child is Text) {
          buffer.write((child.child as Text).data ?? '');
        } else if (child is Expanded && child.child is Text) {
          buffer.write((child.child as Text).data ?? '');
        }
      }
      final res = buffer.toString().trim();
      if (res.isNotEmpty) return res;
    }
    return '';
  }

  String getLabel(T? item) {
    if (item == null) return '';
    if (itemLabel != null) {
      try {
        final label = itemLabel!(item as T);
        if (label.isNotEmpty) return label;
      } catch (_) {
        return '';
      }
    }
    return item.toString();
  }

  @override
  State<AppSearchableDropdown<T>> createState() => _AppSearchableDropdownState<T>();
}

class _AppSearchableDropdownState<T> extends State<AppSearchableDropdown<T>> {
  final LayerLink _layerLink = LayerLink();

  void _showDropdownMenu() {
    if (widget.onChanged == null || widget.items.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final sortedItems = widget.pinAllOption
        ? DropdownHelper.sortOptions<T>(
            widget.items,
            itemLabel: widget.itemLabel,
            pinAll: true,
          )
        : widget.items;

    final menuWidth = widget.dropdownWidth ??
        (widget.width != null ? widget.width!.clamp(240.0, 380.0) : 260.0);

    final estimatedNeededHeight =
        (96.0 + sortedItems.length * 38.0).clamp(120.0, widget.maxDropdownHeight);

    // Calculate vertical position (flip up if not enough space below)
    final spaceBelow = screenSize.height - (targetOffset.dy + targetSize.height);
    final spaceAbove = targetOffset.dy;
    final openUpwards =
        spaceBelow < estimatedNeededHeight + 16 && spaceAbove > spaceBelow;

    // Calculate horizontal position (stay within screen bounds)
    double left = targetOffset.dx;
    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }
    if (left < 12) left = 12;

    double? top;
    double? bottom;
    double maxHeight;
    if (openUpwards) {
      maxHeight = (spaceAbove - 16).clamp(120.0, widget.maxDropdownHeight);
      bottom = (screenSize.height - targetOffset.dy) + 4;
    } else {
      maxHeight = (spaceBelow - 16).clamp(120.0, widget.maxDropdownHeight);
      top = targetOffset.dy + targetSize.height + 4;
    }

    showDialog<_DropdownMenuResult<T>>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogCtx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: menuWidth,
              child: _DropdownMenuPopover<T>(
                label: widget.label ?? 'Option',
                currentValue: widget.value,
                items: sortedItems,
                maxHeight: maxHeight,
                itemLabel: widget.itemLabel,
                itemSubtitle: widget.itemSubtitle,
                itemIcon: widget.itemIcon,
                itemIconColor: widget.itemIconColor,
                itemIcons: widget.itemIcons,
                itemColors: widget.itemColors,
                allowClear: widget.allowClear,
                onSelected: (val) {
                  Navigator.of(dialogCtx).pop(_DropdownMenuResult<T>(val));
                },
              ),
            ),
          ],
        );
      },
    ).then((result) {
      if (result != null && result.value != widget.value) {
        widget.onChanged?.call(result.value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? customSelectedWidget;
    if (widget.selectedItemBuilder != null && widget.items.isNotEmpty && widget.value != null) {
      try {
        final idx = widget.items.indexOf(widget.value as T);
        final builtWidgets = widget.selectedItemBuilder!(context);
        if (idx >= 0 && idx < builtWidgets.length) {
          customSelectedWidget = builtWidgets[idx];
        } else if (builtWidgets.isNotEmpty) {
          customSelectedWidget = builtWidgets.first;
        }
      } catch (_) {}
    }

    final displayValue = widget.value != null
        ? widget.getLabel(widget.value)
        : (widget.hint ?? 'All');

    final strLower = displayValue.toLowerCase();
    final isNonDefault = strLower != 'all' && !strLower.startsWith('all ');

    final isInsideHideUnderline = context.findAncestorWidgetOfExactType<DropdownButtonHideUnderline>() != null;
    final isBorderless = widget.borderless ?? isInsideHideUnderline;

    final borderColor = isBorderless
        ? Colors.transparent
        : (isNonDefault
            ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)));

    final bgColor = isBorderless
        ? Colors.transparent
        : (isNonDefault
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF0F172A) : Colors.white));

    final textColor = widget.style?.color ??
        (isNonDefault
            ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
            : (isDark ? Colors.white : const Color(0xFF1E293B)));

    final labelColor = widget.iconEnabledColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final chevronSize = widget.iconSize ?? (widget.compact ? 16.0 : 18.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth = constraints.hasBoundedWidth;
        final shouldExpand = widget.isExpanded && hasBoundedWidth;
        final double? effectiveWidth = (widget.width != null && widget.width!.isFinite)
            ? widget.width
            : (shouldExpand ? (constraints.maxWidth.isFinite ? constraints.maxWidth : null) : null);

        final bool useExpandedRow = shouldExpand || (effectiveWidth != null);

        Widget contentWidget = customSelectedWidget ?? Text(
          displayValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (widget.style ?? const TextStyle()).copyWith(
            fontSize: widget.style?.fontSize ?? (widget.compact ? 12 : 13),
            fontWeight: widget.style?.fontWeight ??
                (isNonDefault ? FontWeight.w600 : FontWeight.normal),
            color: textColor,
          ),
        );

        if (useExpandedRow) {
          contentWidget = Expanded(child: contentWidget);
        } else if (hasBoundedWidth) {
          contentWidget = Flexible(child: contentWidget);
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: Tooltip(
            message: widget.label != null
                ? '${widget.label}: $displayValue'
                : displayValue,
            waitDuration: const Duration(milliseconds: 700),
            child: InkWell(
              onTap: widget.onChanged != null ? _showDropdownMenu : null,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
              hoverColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              child: Container(
                width: effectiveWidth,
                constraints: BoxConstraints(minHeight: widget.itemHeight ?? 34),
                padding: widget.padding ??
                    EdgeInsets.symmetric(
                      horizontal: isBorderless ? 4 : (widget.compact ? 8 : 12),
                      vertical: isBorderless ? 4 : (widget.compact ? 6 : 8),
                    ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
                  border: isBorderless ? null : Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: useExpandedRow ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (widget.icon is IconData) ...[
                      Icon(
                        widget.icon as IconData,
                        size: widget.compact ? 14 : 16,
                        color: isNonDefault ? const Color(0xFF3B82F6) : labelColor,
                      ),
                      const SizedBox(width: 6),
                    ] else if (widget.icon is Widget) ...[
                      widget.icon as Widget,
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
                    contentWidget,
                    const SizedBox(width: 4),
                    if (widget.underline != null)
                      widget.underline!
                    else
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: chevronSize,
                        color: labelColor,
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
}

class _DropdownMenuPopover<T> extends StatefulWidget {
  final String label;
  final T? currentValue;
  final List<T> items;
  final double maxHeight;
  final String Function(T item)? itemLabel;
  final String? Function(T item)? itemSubtitle;
  final IconData? Function(T item)? itemIcon;
  final Color? Function(T item)? itemIconColor;
  final Map<T, IconData>? itemIcons;
  final Map<T, Color>? itemColors;
  final bool allowClear;
  final ValueChanged<T?> onSelected;

  const _DropdownMenuPopover({
    required this.label,
    required this.currentValue,
    required this.items,
    required this.maxHeight,
    this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.itemIconColor,
    this.itemIcons,
    this.itemColors,
    this.allowClear = false,
    required this.onSelected,
  });

  @override
  State<_DropdownMenuPopover<T>> createState() => _DropdownMenuPopoverState<T>();
}

class _DropdownMenuPopoverState<T> extends State<_DropdownMenuPopover<T>> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
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

  String _getLabel(T? item) {
    if (item == null) return '';
    if (widget.itemLabel != null) {
      try {
        return widget.itemLabel!(item);
      } catch (_) {
        return '';
      }
    }
    return item.toString();
  }

  List<T> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items.where((item) {
      final label = _getLabel(item).toLowerCase();
      final subtitle = widget.itemSubtitle?.call(item)?.toLowerCase() ?? '';
      return label.contains(_searchQuery) || subtitle.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;

    final bgCardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
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
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 16, color: secondaryTextColor),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  splashRadius: 12,
                                  color: secondaryTextColor,
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          hintText: 'Search ${widget.label.toLowerCase()}...',
                          hintStyle:
                              TextStyle(fontSize: 12, color: secondaryTextColor),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${filtered.length} of ${widget.items.length} ${widget.label.toLowerCase()}s',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.currentValue != null &&
                      _getLabel(widget.currentValue).toLowerCase() != 'all' &&
                      !_getLabel(widget.currentValue)
                          .toLowerCase()
                          .startsWith('all '))
                    InkWell(
                      onTap: () {
                        T? allOption;
                        try {
                          allOption = widget.items.firstWhere((item) {
                            final l = _getLabel(item).toLowerCase();
                            return l == 'all' || l.startsWith('all ');
                          });
                        } catch (_) {
                          allOption = null;
                        }
                        widget.onSelected(allOption);
                      },
                      child: Text(
                        'Reset to All',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 24, color: secondaryTextColor),
                          const SizedBox(height: 6),
                          Text(
                            'No matches found',
                            style: TextStyle(
                                fontSize: 12, color: secondaryTextColor),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final label = _getLabel(item);
                        final subtitle = widget.itemSubtitle?.call(item);
                        final isSelected = item == widget.currentValue;
                        final icon = widget.itemIcon?.call(item) ??
                            widget.itemIcons?[item];
                        final iconColor = widget.itemIconColor?.call(item) ??
                            widget.itemColors?[item] ??
                            (isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB));

                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          borderRadius: BorderRadius.circular(6),
                          hoverColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.symmetric(vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFF1E3A8A)
                                          .withValues(alpha: 0.35)
                                      : const Color(0xFFEFF6FF))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, size: 14, color: iconColor),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? (isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color(0xFF1D4ED8))
                                              : textColor,
                                        ),
                                      ),
                                      if (subtitle != null &&
                                          subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: isDark
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF2563EB),
                                  ),
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
}

class _DropdownMenuResult<T> {
  final T? value;
  const _DropdownMenuResult(this.value);
}
