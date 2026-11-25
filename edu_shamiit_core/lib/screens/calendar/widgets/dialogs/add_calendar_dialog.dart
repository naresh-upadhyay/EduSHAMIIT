import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';

class AddCalendarDialog extends StatefulWidget {
  final Function(String name, String color, String type) onSave;

  const AddCalendarDialog({super.key, required this.onSave});

  @override
  State<AddCalendarDialog> createState() => _AddCalendarDialogState();
}

class _AddCalendarDialogState extends State<AddCalendarDialog> {
  final _nameController = TextEditingController();
  Color? _selectedColor;
  String _selectedType = 'custom';

  final List<Color> _colors = const [
    Color(0xFF4F46E5),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final activeColor = _selectedColor ?? primaryColor;

    final List<Color> palette = [
      if (!_colors.any((c) => c.toARGB32() == primaryColor.toARGB32()))
        primaryColor,
      ..._colors,
    ];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width < 600
                ? MediaQuery.sizeOf(context).width - 32
                : 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Custom Calendar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a separate calendar for your department, sports team, or custom project',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 18),

            // Name
            Text(
              'Calendar Name *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13),
              cursorColor: primaryColor,
              decoration: InputDecoration(
                hintText:
                    'e.g. Science Department, Fleet Maintenance, Exam Duties',
                hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    fontSize: 13),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Type
            Text(
              'Calendar Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            AppSearchableDropdownFormField<String>.fromMenuItems(
              key: ValueKey('add_cal_type_$_selectedType'),
              initialValue: _selectedType,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              iconEnabledColor:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom Calendar',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)))),
                DropdownMenuItem(
                    value: 'department',
                    child: Text('Department Calendar',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)))),
                DropdownMenuItem(
                    value: 'academic',
                    child: Text('Academic / Classes',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)))),
                DropdownMenuItem(
                    value: 'transport',
                    child: Text('Transport / Driver Schedule',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)))),
                DropdownMenuItem(
                    value: 'hr',
                    child: Text('HR / Staff Management',
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 16),

            // Color Palette
            Text(
              'Calendar Color',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: palette.map((c) {
                final isSel = c.toARGB32() == activeColor.toARGB32();
                return InkWell(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSel
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF64748B))),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      final hex =
                          '#${(activeColor.r * 255).round().toRadixString(16).padLeft(2, '0')}${(activeColor.g * 255).round().toRadixString(16).padLeft(2, '0')}${(activeColor.b * 255).round().toRadixString(16).padLeft(2, '0')}'
                              .toUpperCase();
                      widget.onSave(name, hex, _selectedType);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Create Calendar',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
