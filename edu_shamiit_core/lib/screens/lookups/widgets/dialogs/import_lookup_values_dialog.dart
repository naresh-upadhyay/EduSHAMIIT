import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/lookup_models.dart';
import '../../providers/lookup_provider.dart';

class ImportLookupValuesDialog extends ConsumerStatefulWidget {
  final LookupKeyModel lookupKey;

  const ImportLookupValuesDialog({super.key, required this.lookupKey});

  @override
  ConsumerState<ImportLookupValuesDialog> createState() => _ImportLookupValuesDialogState();
}

class _ImportLookupValuesDialogState extends ConsumerState<ImportLookupValuesDialog> {
  String? _selectedFileName;
  String? _csvContent;
  List<Map<String, dynamic>> _previewRows = [];
  bool _isLoading = false;

  void _parseCsv(String content) {
    _csvContent = content;
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final rows = <Map<String, dynamic>>[];
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',').map((p) => p.trim().replaceAll('"', '')).toList();
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        rows.add({
          'value_name': parts[0],
          'value_code': parts.length > 1 && parts[1].isNotEmpty ? parts[1] : parts[0].toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_'),
          'status': parts.length > 2 && parts[2].isNotEmpty ? parts[2].toUpperCase() : 'ACTIVE',
          'sort_order': parts.length > 3 ? (int.tryParse(parts[3]) ?? i) : i,
          'description': parts.length > 4 ? parts[4] : '',
        });
      }
    }

    setState(() {
      _previewRows = rows;
    });
  }

  void _downloadTemplate() {
    final key = widget.lookupKey;
    final buffer = StringBuffer();
    buffer.writeln("value_name,value_code,status,sort_order,description");
    buffer.writeln('Sample ${key.keyName} 1,SAMPLE_1,ACTIVE,1,First sample option for ${key.keyName}');
    buffer.writeln('Sample ${key.keyName} 2,SAMPLE_2,ACTIVE,2,Second sample option for ${key.keyName}');
    buffer.writeln('Sample ${key.keyName} 3,SAMPLE_3,INACTIVE,3,Third sample option (inactive)');

    final uri = Uri.dataFromString(
      buffer.toString(),
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloaded CSV template for ${key.keyName}!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _selectedFileName = file.name;
        if (file.bytes != null) {
          final content = utf8.decode(file.bytes!);
          _parseCsv(content);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _import() async {
    if (_previewRows.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final res = await ref.read(lookupProvider.notifier).importValues(
        csvContent: _csvContent,
        values: _previewRows,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Values imported successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 720 ? screenWidth - 32 : 680.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.upload_file_rounded, color: Color(0xFF0EA5E9), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Values from CSV',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Upload a CSV spreadsheet with value columns for ${widget.lookupKey.keyName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Download Template Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.description_outlined, size: 20, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need the CSV format?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Download our pre-formatted template with sample rows, edit in Excel, and upload below.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _downloadTemplate,
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text(
                              'Download Template',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Upload Box
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 32, color: Color(0xFF0EA5E9)),
                            const SizedBox(height: 6),
                            Text(
                              _selectedFileName ?? 'Click to choose CSV file from local device',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Supported format: value_name, value_code, status, sort_order, description',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Preview
                    Text(
                      'Preview Parsed Rows (${_previewRows.length} rows)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: _previewRows.isEmpty
                            ? Center(
                                child: Text(
                                  'Select a CSV file to preview rows here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(10),
                                itemCount: _previewRows.length,
                                separatorBuilder: (_, __) => const Divider(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final r = _previewRows[idx];
                                  return Row(
                                    children: [
                                      Text(
                                        '#${idx + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          r['value_name'].toString(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          r['value_code'].toString(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          r['status'].toString(),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading || _previewRows.isEmpty ? null : _import,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Import ${_previewRows.length} Rows', style: const TextStyle(fontWeight: FontWeight.w700)),
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
