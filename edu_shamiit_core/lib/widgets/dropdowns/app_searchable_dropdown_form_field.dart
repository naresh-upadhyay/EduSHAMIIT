import 'package:flutter/material.dart';

/// Enterprise Searchable Dropdown Form Field.
/// Subclasses Flutter's [FormField] to guarantee 100% full compatibility with
/// [FormState.validate], form resets, validators, onSaved, and InputDecoration.
class AppSearchableDropdownFormField<T> extends FormField<T> {
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final String Function(T item)? itemLabel;
  final String? Function(T item)? itemSubtitle;
  final IconData? Function(T item)? itemIcon;
  final Color? Function(T item)? itemIconColor;
  final InputDecoration decoration;
  final double maxDropdownHeight;
  final double? dropdownWidth;
  final bool allowClear;
  final bool isRequired;
  final bool isDense;
  final bool isExpanded;
  final Color? dropdownColor;
  final Widget? icon;
  final TextStyle? style;
  final DropdownButtonBuilder? selectedItemBuilder;
  final Color? iconEnabledColor;
  final Color? iconDisabledColor;
  final double? iconSize;

  AppSearchableDropdownFormField({
    super.key,
    super.onSaved,
    super.validator,
    T? initialValue,
    T? value,
    super.autovalidateMode,
    super.enabled = true,
    required this.items,
    this.onChanged,
    this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.itemIconColor,
    InputDecoration? decoration,
    String? labelText,
    String? hintText,
    Widget? hint,
    IconData? prefixIcon,
    this.maxDropdownHeight = 340.0,
    this.dropdownWidth,
    this.allowClear = false,
    this.isRequired = false,
    this.isDense = false,
    this.isExpanded = true,
    this.dropdownColor,
    this.icon,
    this.style,
    this.selectedItemBuilder,
    this.iconEnabledColor,
    this.iconDisabledColor,
    this.iconSize,
  })  : decoration = (decoration ??
                InputDecoration(
                  labelText: labelText,
                  hintText: hintText ?? (hint is Text ? hint.data : 'Select option...'),
                  prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
                ))
            .applyDefaults(const InputDecorationTheme()),
        super(
          initialValue: initialValue ?? value,
          builder: (FormFieldState<T> field) {
            final _AppSearchableDropdownFormFieldState<T> state =
                field as _AppSearchableDropdownFormFieldState<T>;

            void onChangeHandler(T? value) {
              field.didChange(value);
              onChanged?.call(value);
            }

            return state.buildField(onChangeHandler);
          },
        );

  /// Drop-in adapter factory constructor that accepts existing `List<DropdownMenuItem<T>>`.
  /// Automatically extracts values and readable labels from existing menu items.
  factory AppSearchableDropdownFormField.fromMenuItems({
    Key? key,
    FormFieldSetter<T>? onSaved,
    FormFieldValidator<T>? validator,
    T? initialValue,
    T? value,
    AutovalidateMode? autovalidateMode,
    bool enabled = true,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
    InputDecoration? decoration,
    String? labelText,
    String? hintText,
    Widget? hint,
    IconData? prefixIcon,
    double maxDropdownHeight = 340.0,
    double? dropdownWidth,
    bool allowClear = false,
    bool isRequired = false,
    bool isDense = false,
    bool isExpanded = true,
    Color? dropdownColor,
    Widget? icon,
    TextStyle? style,
    DropdownButtonBuilder? selectedItemBuilder,
    Color? iconEnabledColor,
    Color? iconDisabledColor,
    double? iconSize,
  }) {
    final Map<T?, String> labelCache = {};
    final List<T> valuesList = [];

    for (final item in items) {
      if (item.value != null) {
        valuesList.add(item.value as T);
      }
      labelCache[item.value] = _extractTextFromWidget(item.child);
    }

    return AppSearchableDropdownFormField<T>(
      key: key,
      onSaved: onSaved,
      validator: validator,
      initialValue: initialValue ?? value,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      items: valuesList,
      itemLabel: (it) => (it == null ? '' : (labelCache[it] ?? it.toString())),
      onChanged: onChanged,
      decoration: decoration,
      labelText: labelText,
      hintText: hintText,
      hint: hint,
      prefixIcon: prefixIcon,
      maxDropdownHeight: maxDropdownHeight,
      dropdownWidth: dropdownWidth,
      allowClear: allowClear,
      isRequired: isRequired,
      isDense: isDense,
      isExpanded: isExpanded,
      dropdownColor: dropdownColor,
      icon: icon,
      style: style,
      selectedItemBuilder: selectedItemBuilder,
      iconEnabledColor: iconEnabledColor,
      iconDisabledColor: iconDisabledColor,
      iconSize: iconSize,
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

  @override
  FormFieldState<T> createState() => _AppSearchableDropdownFormFieldState<T>();
}

class _AppSearchableDropdownFormFieldState<T> extends FormFieldState<T> {
  @override
  AppSearchableDropdownFormField<T> get widget =>
      super.widget as AppSearchableDropdownFormField<T>;

  final LayerLink _layerLink = LayerLink();

  String _getLabel(T? item) {
    if (item == null) return '';
    if (widget.itemLabel != null) {
      try {
        final label = widget.itemLabel!(item);
        if (label.isNotEmpty) return label;
      } catch (_) {
        return '';
      }
    }
    return item.toString();
  }

  void _showDropdownMenu(ValueChanged<T?> onSelected) {
    if (!widget.enabled || widget.items.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    final menuWidth = widget.dropdownWidth ??
        (targetSize.width > 240 ? targetSize.width : 280.0);

    final estimatedNeededHeight =
        (96.0 + widget.items.length * 38.0).clamp(140.0, widget.maxDropdownHeight);

    // Calculate vertical position (flip up if not enough space below)
    final spaceBelow = screenSize.height - (targetOffset.dy + targetSize.height);
    final spaceAbove = targetOffset.dy;
    final openUpwards =
        spaceBelow < estimatedNeededHeight + 16 && spaceAbove > spaceBelow;

    // Calculate horizontal position
    double left = targetOffset.dx;
    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }
    if (left < 12) left = 12;

    double? top;
    double? bottom;
    double maxHeight;
    if (openUpwards) {
      maxHeight = (spaceAbove - 16).clamp(140.0, widget.maxDropdownHeight);
      bottom = (screenSize.height - targetOffset.dy) + 4;
    } else {
      maxHeight = (spaceBelow - 16).clamp(140.0, widget.maxDropdownHeight);
      top = targetOffset.dy + targetSize.height + 4;
    }

    showDialog<_DropdownSelectionResult<T>>(
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
              child: _FormFieldPopoverContent<T>(
                labelText: widget.decoration.labelText ?? 'Option',
                currentValue: value,
                items: widget.items,
                maxHeight: maxHeight,
                itemLabel: widget.itemLabel,
                itemSubtitle: widget.itemSubtitle,
                itemIcon: widget.itemIcon,
                itemIconColor: widget.itemIconColor,
                allowClear: widget.allowClear,
                onSelected: (val) {
                  Navigator.of(dialogCtx).pop(_DropdownSelectionResult<T>(val));
                },
              ),
            ),
          ],
        );
      },
    ).then((result) {
      if (result != null) {
        onSelected(result.value);
      }
    });
  }

  Widget buildField(ValueChanged<T?> onSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel = _getLabel(value);
    final hasVal = displayLabel.isNotEmpty;

    Widget? customSelectedWidget;
    if (widget.selectedItemBuilder != null && widget.items.isNotEmpty && value != null) {
      try {
        final idx = widget.items.indexOf(value as T);
        final builtWidgets = widget.selectedItemBuilder!(context);
        if (idx >= 0 && idx < builtWidgets.length) {
          customSelectedWidget = builtWidgets[idx];
        } else if (builtWidgets.isNotEmpty) {
          customSelectedWidget = builtWidgets.first;
        }
      } catch (_) {}
    }

    final effectiveDecoration = widget.decoration.copyWith(
      errorText: errorText,
      enabled: widget.enabled,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.enabled ? () => _showDropdownMenu(onSelected) : null,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: effectiveDecoration,
          isEmpty: !hasVal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: customSelectedWidget ?? Text(
                  hasVal
                      ? displayLabel
                      : (widget.decoration.hintText ?? 'Select...'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasVal ? FontWeight.w500 : FontWeight.normal,
                    color: hasVal
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8)),
                  ),
                ),
              ),
              if (widget.allowClear && hasVal && widget.enabled)
                InkWell(
                  onTap: () => onSelected(null),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormFieldPopoverContent<T> extends StatefulWidget {
  final String labelText;
  final T? currentValue;
  final List<T> items;
  final double maxHeight;
  final String Function(T item)? itemLabel;
  final String? Function(T item)? itemSubtitle;
  final IconData? Function(T item)? itemIcon;
  final Color? Function(T item)? itemIconColor;
  final bool allowClear;
  final ValueChanged<T?> onSelected;

  const _FormFieldPopoverContent({
    required this.labelText,
    required this.currentValue,
    required this.items,
    required this.maxHeight,
    this.itemLabel,
    this.itemSubtitle,
    this.itemIcon,
    this.itemIconColor,
    this.allowClear = false,
    required this.onSelected,
  });

  @override
  State<_FormFieldPopoverContent<T>> createState() =>
      _FormFieldPopoverContentState<T>();
}

class _FormFieldPopoverContentState<T>
    extends State<_FormFieldPopoverContent<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
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
                        controller: _searchCtrl,
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
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 14),
                                  splashRadius: 12,
                                  color: secondaryTextColor,
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 28, minHeight: 28),
                          hintText:
                              'Search ${widget.labelText.toLowerCase()}...',
                          hintStyle: TextStyle(
                              fontSize: 12, color: secondaryTextColor),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
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
                      '${filtered.length} of ${widget.items.length} ${widget.labelText.toLowerCase()}s',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.allowClear && widget.currentValue != null)
                    InkWell(
                      onTap: () => widget.onSelected(null),
                      child: Text(
                        'Clear Selection',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFDC2626),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final label = _getLabel(item);
                        final subtitle = widget.itemSubtitle?.call(item);
                        final isSelected = item == widget.currentValue;
                        final icon = widget.itemIcon?.call(item);
                        final iconColor = widget.itemIconColor?.call(item) ??
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

class _DropdownSelectionResult<T> {
  final T? value;
  const _DropdownSelectionResult(this.value);
}
