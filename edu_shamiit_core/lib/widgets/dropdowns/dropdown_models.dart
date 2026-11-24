import 'package:flutter/material.dart';

/// Item representation for searchable dropdown selectors.
class AppDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? badge;
  final bool enabled;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.badge,
    this.enabled = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppDropdownItem<T> &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          label == other.label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Helper methods for sorting and filtering dropdown items.
class DropdownHelper {
  /// Sorts items so that any "All" or "All ..." option stays pinned at index 0,
  /// while the rest are sorted alphabetically in a case-insensitive manner.
  static List<T> sortOptions<T>(
    Iterable<T> items, {
    String Function(T item)? itemLabel,
    bool pinAll = true,
  }) {
    final list = items.toList();
    if (list.isEmpty) return list;

    final labelOf = itemLabel ?? (T item) => item?.toString() ?? '';

    if (!pinAll) {
      list.sort((a, b) => labelOf(a).toLowerCase().compareTo(labelOf(b).toLowerCase()));
      return list;
    }

    T? allItem;
    final others = <T>[];

    for (final item in list) {
      final str = labelOf(item).trim().toLowerCase();
      if (str == 'all' || str.startsWith('all ')) {
        if (allItem == null || str == 'all') {
          if (allItem != null && labelOf(allItem).trim().toLowerCase() != 'all') {
            others.add(allItem);
          }
          allItem = item;
          continue;
        }
      }
      others.add(item);
    }

    others.sort((a, b) => labelOf(a).toLowerCase().compareTo(labelOf(b).toLowerCase()));

    if (allItem != null) {
      return [allItem, ...others];
    }
    return others;
  }
}
