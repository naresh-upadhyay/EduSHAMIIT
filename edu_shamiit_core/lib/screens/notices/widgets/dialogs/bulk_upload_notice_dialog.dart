import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/notice_provider.dart';

class BulkUploadNoticeDialog extends ConsumerStatefulWidget {
  const BulkUploadNoticeDialog({super.key});

  @override
  ConsumerState<BulkUploadNoticeDialog> createState() => _BulkUploadNoticeDialogState();
}

class _BulkUploadNoticeDialogState extends ConsumerState<BulkUploadNoticeDialog> {
  final TextEditingController _csvController = TextEditingController();
  List<Map<String, dynamic>> _parsedRows = [];
  bool _isImporting = false;
  bool _isPickingFile = false;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _parseError;
  bool _showManualEditor = false;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  void _downloadSampleTemplate() {
    const csvContent =
        "title,content,category,priority,status,target_scope,target_roles,target_classes,requires_acknowledgement,is_urgent\n"
        "Annual Sports Day Announcement,All students and staff are invited to participate in the Annual Sports Meet.,Event,high,published,entire_institute,,,true,false\n"
        "Parent Teacher Meeting Notice,Term-1 Parent Teacher Meeting will be conducted this Saturday.,Meeting,normal,published,roles,\"parent,teacher\",,false,false\n"
        "Class 10 Revision Schedule,Extra revision classes schedule for Class 10 Board Examinations.,Academic,high,published,classes,,\"10A, 10B\",true,false\n";

    final uri = Uri.dataFromString(
      csvContent,
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);
  }

  Future<void> _pickLocalFile() async {
    setState(() {
      _isPickingFile = true;
      _parseError = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _selectedFileName = file.name;
        _selectedFileSize = file.size;

        if (file.bytes != null) {
          final extension = file.extension?.toLowerCase() ?? '';
          if (extension == 'csv' || extension == 'txt') {
            final content = utf8.decode(file.bytes!, allowMalformed: true);
            _csvController.text = content;
            _parseCsvText(content);
          } else {
            // Excel or binary format fallback
            final content = utf8.decode(file.bytes!, allowMalformed: true);
            if (content.contains('title') && content.contains('content')) {
              _csvController.text = content;
              _parseCsvText(content);
            } else {
              _parseError = 'Selected Excel file format. Please convert to CSV for instant browser parsing, or use the sample template.';
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _parseError = 'Error picking file: $e';
      });
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  void _parseCsvText(String text) {
    setState(() {
      _parseError = null;
      _parsedRows = [];
    });

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      final lines = const LineSplitter().convert(trimmed);
      if (lines.isEmpty) return;

      // Extract Header
      final headerLine = lines.first;
      final headers = _splitCsvLine(headerLine).map((h) => h.trim().toLowerCase()).toList();

      final rows = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final values = _splitCsvLine(line);
        final row = <String, dynamic>{};

        for (int h = 0; h < headers.length; h++) {
          final header = headers[h];
          final val = h < values.length ? values[h].trim() : '';
          row[header] = val;
        }

        // Validate
        final title = (row['title'] ?? '').toString().trim();
        final content = (row['content'] ?? '').toString().trim();
        final isValid = title.isNotEmpty && content.isNotEmpty;

        row['_is_valid'] = isValid;
        row['_error'] = isValid ? null : (title.isEmpty ? 'Title is required' : 'Content is required');
        row['_row_index'] = i;

        rows.add(row);
      }

      setState(() {
        _parsedRows = rows;
        if (rows.isEmpty) {
          _parseError = 'No data rows found. Please check header and format.';
        }
      });
    } catch (e) {
      setState(() {
        _parseError = 'Failed to parse CSV: $e';
      });
    }
  }

  List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  Future<void> _handleImport() async {
    final validRows = _parsedRows.where((r) => r['_is_valid'] == true).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid notices to import!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isImporting = true);

    try {
      final payload = validRows.map((r) {
        final rolesStr = (r['target_roles'] ?? '').toString();
        final classesStr = (r['target_classes'] ?? '').toString();

        return {
          'title': r['title'] ?? '',
          'content': r['content'] ?? '',
          'category': (r['category'] ?? '').toString().isNotEmpty ? r['category'] : 'General',
          'priority': (r['priority'] ?? '').toString().isNotEmpty ? r['priority'] : 'normal',
          'status': (r['status'] ?? '').toString().isNotEmpty ? r['status'] : 'published',
          'target_scope': (r['target_scope'] ?? '').toString().isNotEmpty ? r['target_scope'] : 'entire_institute',
          'target_roles': rolesStr.isNotEmpty ? rolesStr.split(',').map((s) => s.trim().toLowerCase()).toList() : [],
          'target_classes': classesStr.isNotEmpty ? classesStr.split(',').map((s) => s.trim()).toList() : [],
          'requires_acknowledgement': r['requires_acknowledgement']?.toString().toLowerCase() == 'true',
          'is_urgent': r['is_urgent']?.toString().toLowerCase() == 'true' || r['priority']?.toString().toLowerCase() == 'urgent',
        };
      }).toList();

      final res = await ref.read(noticeProvider.notifier).bulkImportNotices(payload);

      if (mounted) {
        Navigator.of(context).pop();
        final data = res['data'] is Map ? res['data'] as Map : res;
        final count = data['imported_count'] ?? res['imported_count'] ?? validRows.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $count notice${count > 1 ? "s" : ""}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validCount = _parsedRows.where((r) => r['_is_valid'] == true).length;
    final errorCount = _parsedRows.where((r) => r['_is_valid'] == false).length;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upload_file_rounded, size: 22, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload Notice (Bulk)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select a CSV file from your computer to import multiple notices at once',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Export Template Button
                  ElevatedButton.icon(
                    onPressed: _downloadSampleTemplate,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export Template (.CSV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2FF),
                      foregroundColor: const Color(0xFF4F46E5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // File Picker Dropzone Card
                  InkWell(
                    onTap: _isPickingFile ? null : _pickLocalFile,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedFileName != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF4F46E5).withOpacity(0.4),
                          width: 1.8,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: _selectedFileName != null
                                  ? const Color(0xFF10B981).withOpacity(0.12)
                                  : const Color(0xFF4F46E5).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                              size: 28,
                              color: _selectedFileName != null ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFileName != null) ...[
                            Text(
                              _selectedFileName!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_selectedFileSize ?? 0) / 1024 > 0 ? ((_selectedFileSize ?? 0) / 1024).toStringAsFixed(1) : "1"} KB  •  Click to change file',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ] else ...[
                            Text(
                              'Click to Select File from Local Computer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supported format: .csv, .xlsx, .txt (Comma Separated Values)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions row below dropzone
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPickingFile ? null : _pickLocalFile,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(_isPickingFile ? 'Selecting...' : 'Browse Local File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () {
                          _csvController.text =
                              "title,content,category,priority,status,target_scope,target_roles,target_classes,requires_acknowledgement,is_urgent\n"
                              "Term 1 Final Examination Schedule,The final exam schedule is available for all classes.,Examination,high,published,entire_institute,,,true,false\n"
                              "Staff Meeting Tomorrow,All faculty members attend the annual staff review at 3 PM.,Meeting,urgent,published,roles,teacher,,true,true\n"
                              "Grade 10 Lab Safety Guidelines,Important chemistry lab guidelines for Class 10.,Academic,normal,published,classes,,\"10A, 10B\",false,false";
                          _selectedFileName = "sample_notices_demo.csv";
                          _selectedFileSize = 1024;
                          _parseCsvText(_csvController.text);
                        },
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFF6366F1)),
                        label: const Text('Load Demo Sample Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _showManualEditor = !_showManualEditor),
                        child: Text(
                          _showManualEditor ? 'Hide Text Editor' : 'Edit / Paste CSV Manually',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  // Collapsible manual text editor
                  if (_showManualEditor) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _csvController,
                      maxLines: 4,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      decoration: InputDecoration(
                        hintText: "title,content,category,priority,status,target_scope,target_roles,target_classes\nNotice 1,Content 1,General,normal,published,entire_institute,,",
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) => _parseCsvText(val),
                    ),
                  ],

                  if (_parseError != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _parseError!,
                              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Parsed Rows Table Preview
                  if (_parsedRows.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'File Content Preview (${_parsedRows.length} rows found):',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('$validCount Valid', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                            ),
                            if (errorCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('$errorCount Errors', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 38,
                            dataRowMinHeight: 42,
                            dataRowMaxHeight: 48,
                            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            columns: const [
                              DataColumn(label: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Audience / Scope', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Target Roles / Classes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                            ],
                            rows: _parsedRows.map((r) {
                              final isValid = r['_is_valid'] == true;
                              return DataRow(
                                color: isValid ? null : WidgetStateProperty.all(const Color(0xFFEF4444).withOpacity(0.08)),
                                cells: [
                                  DataCell(
                                    isValid
                                        ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981))
                                        : Tooltip(
                                            message: r['_error'] ?? 'Invalid row',
                                            child: const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                          ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 240),
                                      child: Text(
                                        r['title'] ?? '',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isValid ? null : const Color(0xFFEF4444)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(r['category'] ?? 'General', style: const TextStyle(fontSize: 11))),
                                  DataCell(Text((r['priority'] ?? 'normal').toString().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                                  DataCell(Text(r['target_scope'] ?? 'entire_institute', style: const TextStyle(fontSize: 11))),
                                  DataCell(Text(r['target_roles'] ?? r['target_classes'] ?? '-', style: const TextStyle(fontSize: 11))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isImporting || validCount == 0 ? null : _handleImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isImporting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Import $validCount Notice${validCount != 1 ? "s" : ""} to System', style: const TextStyle(fontWeight: FontWeight.w700)),
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
