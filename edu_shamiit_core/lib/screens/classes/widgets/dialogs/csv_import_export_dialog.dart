import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/class_provider.dart';
import '../../services/class_api_service.dart';

class CsvImportExportDialog extends ConsumerStatefulWidget {
  final int initialEntityIndex; // 0: Classes, 1: Sections, 2: Subjects, 3: Rooms

  const CsvImportExportDialog({
    super.key,
    this.initialEntityIndex = 0,
  });

  @override
  ConsumerState<CsvImportExportDialog> createState() => _CsvImportExportDialogState();
}

class _CsvImportExportDialogState extends ConsumerState<CsvImportExportDialog> {
  final ClassApiService _apiService = ClassApiService();
  late int _selectedEntityIndex;
  bool _isDownloading = false;
  bool _isImporting = false;
  bool _isPickingFile = false;

  String? _selectedFileName;
  int? _selectedFileSize;
  String? _rawCsvContent;
  List<String> _csvHeaders = [];
  List<List<String>> _previewRows = [];
  List<Map<String, dynamic>> _parsedJsonRecords = [];
  String? _parseError;

  // Import Result
  Map<String, dynamic>? _importResult;
  String? _statusMessage;

  final List<Map<String, dynamic>> _entities = const [
    {
      'name': 'classes',
      'label': 'Classes & Grades',
      'icon': Icons.class_outlined,
      'columns': ['Class Name*', 'Code*', 'Stage', 'Academic Year', 'Display Order', 'Status'],
      'sample': "Class Name,Code,Stage,Academic Year,Display Order,Status\n"
          "Class 9,C9,Secondary,2026-27,9,ACTIVE\n"
          "Class 10,C10,Secondary,2026-27,10,ACTIVE\n"
          "Class 11,C11,Higher Secondary,2026-27,11,ACTIVE\n"
          "Class 12,C12,Higher Secondary,2026-27,12,ACTIVE\n",
    },
    {
      'name': 'sections',
      'label': 'Sections & Batches',
      'icon': Icons.grid_view_rounded,
      'columns': ['Class*', 'Section Name*', 'Section Code*', 'Capacity', 'Room', 'Status'],
      'sample': "Class,Section Name,Section Code,Capacity,Room,Status\n"
          "Class 10,Section A,10A,40,Room 101,ACTIVE\n"
          "Class 10,Section B,10B,40,Room 102,ACTIVE\n"
          "Class 11,Section Science,11SCI,35,Lab 01,ACTIVE\n"
          "Class 11,Section Commerce,11COM,35,Room 201,ACTIVE\n",
    },
    {
      'name': 'subjects',
      'label': 'Subjects Catalog',
      'icon': Icons.menu_book_rounded,
      'columns': ['Subject Name*', 'Code*', 'Type', 'Status'],
      'sample': "Subject Name,Code,Type,Status\n"
          "Advanced Mathematics,MATH10,Core,ACTIVE\n"
          "English Literature,ENG10,Core,ACTIVE\n"
          "Physics,PHY11,Core,ACTIVE\n"
          "Computer Science,CS10,Elective,ACTIVE\n",
    },
    {
      'name': 'rooms',
      'label': 'Rooms & Facilities',
      'icon': Icons.meeting_room_outlined,
      'columns': ['Room Name*', 'Room Code*', 'Type', 'Building', 'Floor', 'Capacity', 'Facilities', 'Status'],
      'sample': "Room Name,Room Code,Type,Building,Floor,Capacity,Facilities,Status\n"
          "Classroom 101,CR-101,Classroom,Academic Block,1st Floor,40,\"Projector, AC, Smart Board\",AVAILABLE\n"
          "Classroom 102,CR-102,Classroom,Academic Block,1st Floor,40,\"Projector, AC\",AVAILABLE\n"
          "Physics Lab,PHY-LAB-01,Laboratory,Science Block,2nd Floor,35,\"AC, Laboratory Equipment, Projector\",AVAILABLE\n"
          "Computer Lab 1,COMP-01,Computer Lab,IT Block,Ground Floor,30,\"Computers, AC, Projector\",AVAILABLE\n",
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedEntityIndex = widget.initialEntityIndex.clamp(0, _entities.length - 1);
  }

  void _onEntityChanged(int newIndex) {
    if (_selectedEntityIndex == newIndex) return;
    setState(() {
      _selectedEntityIndex = newIndex;
      _selectedFileName = null;
      _selectedFileSize = null;
      _rawCsvContent = null;
      _csvHeaders = [];
      _previewRows = [];
      _parsedJsonRecords = [];
      _parseError = null;
      _importResult = null;
      _statusMessage = null;
    });
  }

  /// 1. Download Sample CSV Template
  Future<void> _downloadTemplate() async {
    final entityMap = _entities[_selectedEntityIndex];
    final entity = entityMap['name'] as String;
    final sampleCsv = entityMap['sample'] as String;

    try {
      final uri = Uri.dataFromString(
        sampleCsv,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      await launchUrl(uri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Downloaded CSV template for ${entityMap['label']}!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download template: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 2. Export Live Dataset from Server
  Future<void> _triggerExport() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = null;
    });

    final entityMap = _entities[_selectedEntityIndex];
    final entity = entityMap['name'] as String;
    final academicYear = ref.read(classProvider).academicYear;

    try {
      final csvText = await _apiService.exportCsv(entity, academicYear: academicYear);
      final uri = Uri.dataFromString(
        csvText,
        mimeType: 'text/csv',
        encoding: utf8,
      );
      await launchUrl(uri);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Exported ${entityMap['label']} dataset successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Exported ${entityMap['label']} for AY $academicYear!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Export error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 3. Pick File from Local Device
  Future<void> _pickFile() async {
    setState(() {
      _isPickingFile = true;
      _parseError = null;
      _importResult = null;
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
          final content = utf8.decode(file.bytes!, allowMalformed: true);
          _parseCsv(content);
        }
      }
    } catch (e) {
      setState(() => _parseError = 'Error picking file: $e');
    } finally {
      if (mounted) setState(() => _isPickingFile = false);
    }
  }

  /// Parse CSV content into preview and structured JSON rows
  void _parseCsv(String content) {
    _rawCsvContent = content;
    final cleanContent = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim().lstrip('\ufeff');
    final rawLines = cleanContent.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (rawLines.isEmpty) {
      setState(() => _parseError = 'The selected file is empty.');
      return;
    }

    final headerLine = rawLines.first;
    final headers = _splitCsvLine(headerLine).map((h) => h.trim().replaceAll('"', '')).toList();

    final previewRows = <List<String>>[];
    final jsonRecords = <Map<String, dynamic>>[];

    for (int i = 1; i < rawLines.length; i++) {
      final parts = _splitCsvLine(rawLines[i]).map((p) => p.trim().replaceAll('"', '')).toList();
      if (parts.isEmpty || parts.every((p) => p.isEmpty)) continue;

      if (previewRows.length < 5) {
        previewRows.add(parts);
      }

      final rowMap = <String, dynamic>{};
      for (int h = 0; h < headers.length; h++) {
        if (h < parts.length) {
          rowMap[headers[h]] = parts[h];
        }
      }
      jsonRecords.add(rowMap);
    }

    setState(() {
      _csvHeaders = headers;
      _previewRows = previewRows;
      _parsedJsonRecords = jsonRecords;
      _parseError = jsonRecords.isEmpty ? 'No data rows found in the CSV file.' : null;
    });
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == ',' && !insideQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// 4. Submit & Bulk Import Data to Server
  Future<void> _submitImport() async {
    if (_parsedJsonRecords.isEmpty) return;

    setState(() {
      _isImporting = true;
      _statusMessage = null;
      _parseError = null;
    });

    final entity = _entities[_selectedEntityIndex]['name'] as String;
    final academicYear = ref.read(classProvider).academicYear;

    try {
      final res = await _apiService.importCsv(
        entity,
        csvContent: _rawCsvContent,
        records: _parsedJsonRecords,
        academicYear: academicYear,
      );

      setState(() {
        _isImporting = false;
        _importResult = res;
      });

      // Refresh providers so updated records appear on screen immediately
      final notifier = ref.read(classProvider.notifier);
      notifier.fetchStats();
      if (entity == 'classes') {
        notifier.fetchClasses();
        notifier.fetchAllClasses();
      } else if (entity == 'sections') {
        notifier.fetchSections();
        notifier.fetchSectionsOverviewStats();
      } else if (entity == 'subjects') {
        notifier.fetchSubjects();
      } else if (entity == 'rooms') {
        notifier.fetchRooms();
      }

      if (mounted) {
        final importedCount = res['imported_count'] ?? 0;
        final failedCount = res['failed_count'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  failedCount == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(res['message']?.toString() ?? 'Bulk import completed! ($importedCount imported, $failedCount failed)'),
              ],
            ),
            backgroundColor: failedCount == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _parseError = 'Import error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedEntity = _entities[_selectedEntityIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.9).clamp(520.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.import_export_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulk Import & Export Center',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Download templates, export datasets, and bulk import records',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Select Academic Entity Tabs
              Text(
                'Select Academic Entity',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(_entities.length, (idx) {
                  final e = _entities[idx];
                  final isSelected = _selectedEntityIndex == idx;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _onEntityChanged(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        margin: EdgeInsets.only(right: idx < _entities.length - 1 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5).withOpacity(0.12)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4F46E5)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              e['icon'] as IconData,
                              size: 20,
                              color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (e['label'] as String).split(' ').first,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Status message (if any)
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF34D399)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(color: Color(0xFF059669), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // -------------------------------------------------------------
              // STEP 1: DOWNLOAD SAMPLE TEMPLATE (BEFORE UPLOAD)
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.table_chart_outlined, color: Color(0xFF4F46E5), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '1. Download Template',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Recommended First',
                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Download sample .csv template with columns & format pre-configured for ${selectedEntity['label']}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Download CSV Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Expected columns chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (selectedEntity['columns'] as List<String>).map((col) {
                        final isMandatory = col.contains('*');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isMandatory
                                ? (isDark ? const Color(0xFF312E81).withOpacity(0.5) : const Color(0xFFEEF2FF))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isMandatory ? const Color(0xFF6366F1).withOpacity(0.4) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Text(
                            col,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isMandatory ? FontWeight.w700 : FontWeight.w500,
                              color: isMandatory ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // -------------------------------------------------------------
              // STEP 2: EXPORT LIVE DATASET
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. Export Current ${selectedEntity['label']}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Download all active ${selectedEntity['label']} records for the current academic year as CSV',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : _triggerExport,
                      icon: _isDownloading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // -------------------------------------------------------------
              // STEP 3: UPLOAD & BULK IMPORT
              // -------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _parsedJsonRecords.isNotEmpty ? const Color(0xFF10B981).withOpacity(0.5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.upload_file_rounded, color: Color(0xFF8B5CF6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '3. Upload & Bulk Import',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Upload completed .csv spreadsheet to bulk create or update records',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isPickingFile ? null : _pickFile,
                          icon: _isPickingFile
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.folder_open_rounded, size: 16),
                          label: Text(_selectedFileName != null ? 'Change File' : 'Choose File', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),

                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_selectedFileName (${(_selectedFileSize ?? 0) / 1024 > 1 ? '${((_selectedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB' : '${_selectedFileSize ?? 0} B'}) • ${_parsedJsonRecords.length} records detected',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_parseError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF87171)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_parseError!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Data Preview Table (First 5 Rows)
                    if (_previewRows.isNotEmpty && _csvHeaders.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Data Preview (First ${_previewRows.length} of ${_parsedJsonRecords.length} rows)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                            ),
                          ),
                          Text(
                            '${_parsedJsonRecords.length} Total Rows',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 36,
                            headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            columns: _csvHeaders.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)))).toList(),
                            rows: _previewRows.map((row) {
                              return DataRow(
                                cells: List.generate(_csvHeaders.length, (colIdx) {
                                  final val = colIdx < row.length ? row[colIdx] : '';
                                  return DataCell(Text(val, style: const TextStyle(fontSize: 11)));
                                }),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isImporting ? null : _submitImport,
                          icon: _isImporting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: Text(
                            _isImporting ? 'Importing Dataset...' : 'Upload & Import ${_parsedJsonRecords.length} Records',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],

                    // Import Results Card
                    if (_importResult != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: (_importResult!['failed_count'] ?? 0) == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_importResult!['failed_count'] ?? 0) == 0 ? const Color(0xFF34D399) : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  (_importResult!['failed_count'] ?? 0) == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  color: (_importResult!['failed_count'] ?? 0) == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _importResult!['message']?.toString() ?? 'Import processing complete.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: (_importResult!['failed_count'] ?? 0) == 0 ? const Color(0xFF065F46) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if ((_importResult!['errors'] as List? ?? []).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Errors Encountered:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C))),
                              const SizedBox(height: 4),
                              ...((_importResult!['errors'] as List).take(5).map((err) => Text('• $err', style: const TextStyle(fontSize: 10.5, color: Color(0xFFB91C1C))))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
extension StringExtensions on String {
  String lstrip(String pattern) {
    if (startsWith(pattern)) {
      return substring(pattern.length);
    }
    return this;
  }
}
