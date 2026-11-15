import 'package:flutter/material.dart';
import '../core/theme.dart';

class FilterChipsBar extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipsBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt.startsWith(selected) || opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelected(opt.split(' ').first),
              selectedColor: AppColors.primaryBlue,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primaryBlue : AppColors.borderSubtle,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}
