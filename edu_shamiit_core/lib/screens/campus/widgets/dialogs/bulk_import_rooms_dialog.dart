import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/campus_api_service.dart';

class BulkImportRoomsDialog extends StatefulWidget {
  final VoidCallback onImportCompleted;

  const BulkImportRoomsDialog({
    super.key,
    required this.onImportCompleted,
  });

  @override
  State<BulkImportRoomsDialog> createState() => _BulkImportRoomsDialogState();
}

class _BulkImportRoomsDialogState extends State<BulkImportRoomsDialog> {
  final _csvCtrl = TextEditingController(
    text: '''building_code,floor_code,room_number,room_name,room_type,capacity,status
B1,G,G009,Primary Robotics Lab,Computer Lab,30,Available
B1,G,G010,Counselor Office,Administrative Office,10,Available
B1,F1,109,Language Practice Studio,Smart Classroom,40,Available''',
  );

  bool _isImporting = false;
  String? _error;
  Map<String, dynamic>? _importResult;

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _csvCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please enter CSV content.');
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
      _importResult = null;
    });

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length <= 1) {
      setState(() {
        _isImporting = false;
        _error = 'CSV must contain at least one data row below header.';
      });
      return;
    }

    List<String> parseCsvLine(String line) {
      final result = <String>[];
      final sb = StringBuffer();
      bool inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (c == ',' && !inQuotes) {
          result.add(sb.toString().trim());
          sb.clear();
        } else {
          sb.write(c);
        }
      }
      result.add(sb.toString().trim());
      return result;
    }

    final headers = parseCsvLine(lines.first).map((h) => h.toLowerCase()).toList();
    final rows = <Map<String, dynamic>>[];

    for (int i = 1; i < lines.length; i++) {
      final parts = parseCsvLine(lines[i]);
      if (parts.length != headers.length) continue;

      final row = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = parts[j];
      }
      rows.add(row);
    }

    final res = await CampusApiService.instance.bulkImportRooms(rows);

    if (mounted) {
      setState(() {
        _isImporting = false;
        _importResult = res;
      });
      if (res['success'] == true && (res['imported_count'] ?? 0) > 0) {
        widget.onImportCompleted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(620.0, screenWidth * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bulk Import Rooms',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(height: 16),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            if (_importResult != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Summary: ${_importResult!['imported_count']} rooms imported, ${_importResult!['failed_count']} failed.',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF059669)),
                    ),
                    if (_importResult!['errors'] != null && (_importResult!['errors'] as List).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...(_importResult!['errors'] as List).take(3).map((err) => Text('• ${err['error']}', style: const TextStyle(fontSize: 11.5, color: Colors.red))),
                    ],
                  ],
                ),
              ),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: const Text(
                            'Paste CSV Data (Header: building_code, floor_code, room_number, room_name, room_type, capacity, status):',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            CampusApiService.instance.exportData('rooms');
                          },
                          icon: const Icon(Icons.file_download, size: 14),
                          label: const Text('Download Sample CSV', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _csvCtrl,
                      maxLines: 8,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'building_code,floor_code,room_number,room_name,room_type,capacity,status...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _submit,
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload, size: 16, color: Colors.white),
                  label: const Text('Process Import', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
