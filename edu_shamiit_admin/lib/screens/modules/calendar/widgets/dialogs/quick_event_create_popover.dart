import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      child: Container(
        width: 360,
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
                Text(
                  '${DateFormat('d MMMM').format(start)} • ${DateFormat('hh:mm a').format(start)} – ${DateFormat('hh:mm a').format(end)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type selector
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: 'Schedule Type',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                DropdownMenuItem(value: 'Class', child: Text('Class')),
                DropdownMenuItem(value: 'Task', child: Text('Task')),
                DropdownMenuItem(value: 'Reminder', child: Text('Reminder')),
                DropdownMenuItem(value: 'Trip', child: Text('Trip (Transport)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
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
