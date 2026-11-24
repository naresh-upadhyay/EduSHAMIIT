import 'package:flutter/material.dart';

/// Item definition for CampusSearchableDropdown
class CampusSearchableDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? badge;

  const CampusSearchableDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.badge,
  });
}

/// Production-Grade Searchable Filter Dropdown for Campus Management
/// Displays a sleek filter pill in the toolbar, and opens a searchable popover/dialog
/// with instant client-side query filtering, item counts, and selection checkmarks.
class CampusSearchableDropdown<T> extends StatelessWidget {
  final String title;
  final String label;
  final T value;
  final List<CampusSearchableDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? searchHint;
  final IconData? prefixIcon;
  final bool isDark;
  final double? minWidth;
  final double? maxWidth;
  final T? allValue;
  final bool isRequired;

  const CampusSearchableDropdown({
    super.key,
    required this.title,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.searchHint,
    this.prefixIcon,
    required this.isDark,
    this.minWidth,
    this.maxWidth,
    this.allValue,
    this.isRequired = false,
  });

  bool get _isActiveFilter {
    if (allValue != null) {
      return value != allValue;
    }
    final strVal = value.toString().toLowerCase();
    return strVal != 'all' && strVal != 'any' && strVal != 'any capacity' && strVal.isNotEmpty;
  }

  CampusSearchableDropdownItem<T>? get _selectedItem {
    try {
      return items.firstWhere((i) => i.value == value);
    } catch (_) {
      return items.isNotEmpty ? items.first : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
        : const Color(0xFFEFF6FF);
    final normalBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    const activeBorder = Color(0xFF3B82F6);
    final normalBorder = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    const activeText = Color(0xFF3B82F6);
    final normalText = isDark ? Colors.white : const Color(0xFF1E293B);

    final displayLabel = _selectedItem != null ? _selectedItem!.label : label;

    return Tooltip(
      message: '$title: $displayLabel',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => _openSearchDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          constraints: BoxConstraints(
            minWidth: minWidth ?? 110,
            maxWidth: maxWidth ?? 220,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
          decoration: BoxDecoration(
            color: _isActiveFilter ? activeBg : normalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isActiveFilter ? activeBorder : normalBorder,
              width: _isActiveFilter ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (prefixIcon != null) ...[
                Icon(
                  prefixIcon,
                  size: 14,
                  color: _isActiveFilter ? activeText : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _isActiveFilter ? FontWeight.w700 : FontWeight.w500,
                    color: _isActiveFilter ? activeText : normalText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: _isActiveFilter ? activeText : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _SearchDialog<T>(
        title: title,
        searchHint: searchHint ?? 'Search $title...',
        initialValue: value,
        items: items,
        isDark: isDark,
        onSelected: (selected) {
          Navigator.pop(ctx);
          onChanged(selected);
        },
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final T initialValue;
  final List<CampusSearchableDropdownItem<T>> items;
  final bool isDark;
  final ValueChanged<T> onSelected;

  const _SearchDialog({
    required this.title,
    required this.searchHint,
    required this.initialValue,
    required this.items,
    required this.isDark,
    required this.onSelected,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  late TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final filtered = widget.items.where((item) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      final inLabel = item.label.toLowerCase().contains(q);
      final inSub = item.subtitle?.toLowerCase().contains(q) ?? false;
      final inVal = item.value.toString().toLowerCase().contains(q);
      return inLabel || inSub || inVal;
    }).toList();

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.filter_list_rounded, size: 16, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${filtered.length} of ${widget.items.length}',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Live Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 12.5, color: textPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(fontSize: 12, color: textMuted),
                  prefixIcon: Icon(Icons.search, size: 18, color: textMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),

            // Items List
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 36, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'No matching options found for "${_query.trim()}"',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(color: borderColor.withValues(alpha: 0.5), height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.value == widget.initialValue;

                        return InkWell(
                          onTap: () => widget.onSelected(item.value),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (widget.isDark
                                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                                      : const Color(0xFFEFF6FF))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: 16,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (item.iconColor ?? (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? const Color(0xFF2563EB) : textPrimary,
                                        ),
                                      ),
                                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.badge != null) ...[
                                  const SizedBox(width: 8),
                                  item.badge!,
                                ],
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer info / Cancel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(fontSize: 12, color: textMuted)),
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
