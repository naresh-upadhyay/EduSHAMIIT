import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../classes/services/academic_lookup_helper.dart';

class QuickEventCreatePopover extends StatefulWidget {
  final DateTime selectedDate;
  final int hour;
  final Function(String title, String type, DateTime start, DateTime end) onSave;
  final VoidCallback onMoreOptions;

  const QuickEventCreatePopover({
    super.key,
    required this.selectedDate,
    required this.hour,
    required this.onSave,
    required this.onMoreOptions,
  });

  @override
  State<QuickEventCreatePopover> createState() => _QuickEventCreatePopoverState();
}

class _QuickEventCreatePopoverState extends State<QuickEventCreatePopover> {
  final _titleController = TextEditingController();
  String _selectedType = 'Meeting';
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final items = await AcademicLookupHelper.instance.getActiveLookup('CALENDAR_CATEGORY', forceRefresh: true);
      if (items.isNotEmpty && mounted) {
        setState(() {
          _categories = items.map((i) => {'code': i.code, 'name': i.label, 'label': i.label}).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, widget.hour, 0);
    final end = start.add(const Duration(hours: 1));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width < 600 ? MediaQuery.sizeOf(context).width - 32 : 360),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'New Schedule',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Add title (e.g. Team Meeting)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // Time & Date summary
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('d MMM').format(start)} • ${DateFormat('hh:mm a').format(start)} – ${DateFormat('hh:mm a').format(end)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type selector
            Builder(
              builder: (context) {
                final List<Map<String, dynamic>> list = _categories.isNotEmpty
                    ? _categories
                    : [
                        {'name': 'Academic', 'label': 'Academic'},
                        {'name': 'Event', 'label': 'Event'},
                        {'name': 'Holiday', 'label': 'Holiday'},
                        {'name': 'Meeting', 'label': 'Meeting'},
                        {'name': 'Examination', 'label': 'Examination'},
                        {'name': 'Reminder', 'label': 'Reminder'},
                        {'name': 'Personal', 'label': 'Personal'},
                        {'name': 'Task', 'label': 'Task'},
                        {'name': 'Class', 'label': 'Class'},
                        {'name': 'Training', 'label': 'Training'},
                        {'name': 'Trip', 'label': 'Trip (Transport)'},
                        {'name': 'Leave', 'label': 'Leave'},
                        {'name': 'General', 'label': 'General'},
                        {'name': 'Sports', 'label': 'Sports'},
                        {'name': 'Anniversary', 'label': 'Anniversary'},
                      ];
                final map = <String, String>{};
                for (final c in list) {
                  final name = c['name']?.toString() ?? c['label']?.toString() ?? '';
                  final label = c['label']?.toString() ?? name;
                  if (name.isNotEmpty) map[name] = label;
                }
                String current = _selectedType;
                final match = map.keys.firstWhere((k) => k.toLowerCase() == current.toLowerCase(), orElse: () => '');
                if (match.isNotEmpty) {
                  current = match;
                } else {
                  map[current] = current;
                }
                return DropdownButtonFormField<String>(
                  initialValue: current,
                  decoration: InputDecoration(
                    labelText: 'Schedule Type',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: map.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onMoreOptions();
                  },
                  child: const Text('More Options', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    final title = _titleController.text.trim();
                    if (title.isNotEmpty) {
                      widget.onSave(title, _selectedType, start, end);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
