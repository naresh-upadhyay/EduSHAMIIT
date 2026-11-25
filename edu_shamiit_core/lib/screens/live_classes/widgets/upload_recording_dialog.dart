import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/live_class_management_provider.dart';
import '../../classes/providers/class_provider.dart';

class UploadRecordingDialog extends ConsumerStatefulWidget {
  const UploadRecordingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const UploadRecordingDialog(),
    );
  }

  @override
  ConsumerState<UploadRecordingDialog> createState() => _UploadRecordingDialogState();
}

class _UploadRecordingDialogState extends ConsumerState<UploadRecordingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController(text: 'Class 10 - Conceptual Synthesis Lecture');
  final _teacherCtrl = TextEditingController(text: 'King Doe');
  final _durationCtrl = TextEditingController(text: '45');
  final _fileSizeCtrl = TextEditingController(text: '282.5');
  final _descCtrl = TextEditingController(text: 'Complete classroom lecture notes and live recording with interactive board synthesis.');

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  String _visibility = 'CLASS';

  PlatformFile? _pickedFile;
  String? _selectedFileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classProvider.notifier).fetchClasses();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _durationCtrl.dispose();
    _fileSizeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4', 'webm', 'mkv', 'mov', 'avi', 'flv', 'wmv',
          'pdf', 'doc', 'docx', 'ppt', 'pptx', 'zip', 'csv', 'txt'
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _selectedFileName = file.name;
          final sizeMb = file.size / (1024 * 1024);
          _fileSizeCtrl.text = sizeMb > 0 ? sizeMb.toStringAsFixed(1) : '15.5';

          // Auto-derive clean title if unchanged from default
          if (_titleCtrl.text.isEmpty || _titleCtrl.text == 'Class 10 - Conceptual Synthesis Lecture') {
            final clean = file.name
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceAll(RegExp(r'[_\-]+'), ' ')
                .trim();
            if (clean.isNotEmpty) {
              _titleCtrl.text = clean;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[UploadRecordingDialog] Pick file error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access local file picker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleUpload({
    required String className,
    required String sectionName,
    required String subjectName,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null || _pickedFile!.bytes == null || _pickedFile!.bytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video file from your device before publishing.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.25;
    });

    final durationMin = int.tryParse(_durationCtrl.text.trim()) ?? 1;
    final sizeMb = double.tryParse(_fileSizeCtrl.text.trim()) ??
        (_pickedFile!.size / (1024 * 1024));
    final classSection = '$className - $sectionName';

    final success = await ref.read(liveClassManagementProvider.notifier).uploadRecording(
      title: _titleCtrl.text.trim(),
      classId: _selectedClassId ?? '',
      sectionId: _selectedSectionId,
      classSection: classSection,
      subjectId: _selectedSubjectId ?? '',
      subjectName: subjectName,
      teacherName: _teacherCtrl.text.trim(),
      durationMinutes: durationMin,
      fileSizeMb: sizeMb,
      fileBytes: _pickedFile!.bytes,
      fileName: _pickedFile!.name,
      description: _descCtrl.text.trim(),
      visibility: _visibility,
    );

    if (mounted) {
      setState(() => _uploadProgress = 1.0);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Recording "${_titleCtrl.text.trim()}" uploaded & published successfully.'
              : 'Upload failed. Please ensure valid video format (.mp4/.webm/.mkv) and connection.'),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final meta = ref.watch(liveClassManagementProvider).dropdownMeta;
    final classState = ref.watch(classProvider);

    // =========================================================================
    // Build Cascading Datasets strictly in order: Class -> Section -> Subject
    // =========================================================================
    final classMap = <String, Map<String, dynamic>>{};

    // 1. Ingest from Class Management (classProvider - Image 2)
    for (final c in classState.availableClasses) {
      if (c.id.isNotEmpty && c.name.isNotEmpty) {
        classMap[c.id] = <String, dynamic>{
          'id': c.id,
          'name': c.name,
          'sections': c.sections
              .map<Map<String, dynamic>>((s) => <String, dynamic>{'id': s.id, 'name': s.name})
              .toList(),
          'subjects': c.subjects
              .map<Map<String, dynamic>>((sub) => <String, dynamic>{'id': sub.id, 'name': sub.name})
              .toList(),
        };
      }
    }

    // 2. Ingest from LiveClassManagement metadata dropdowns
    if (meta != null) {
      for (final c in meta.classes) {
        if (!classMap.containsKey(c.id)) {
          classMap[c.id] = <String, dynamic>{
            'id': c.id,
            'name': c.name,
            'sections': <Map<String, dynamic>>[],
            'subjects': <Map<String, dynamic>>[],
          };
        }
      }
      for (final s in meta.sections) {
        if (classMap.containsKey(s.classId)) {
          final existing = classMap[s.classId]!['sections'] as List<Map<String, dynamic>>;
          if (!existing.any((e) => e['id'] == s.id || e['name'] == s.name)) {
            existing.add(<String, dynamic>{'id': s.id, 'name': s.name});
          }
        }
      }
      for (final cs in meta.classSubjects) {
        if (classMap.containsKey(cs.classId)) {
          final existing = classMap[cs.classId]!['subjects'] as List<Map<String, dynamic>>;
          if (!existing.any((e) => e['id'] == cs.subjectId || e['name'] == cs.subjectName)) {
            existing.add(<String, dynamic>{'id': cs.subjectId, 'name': cs.subjectName});
          }
        }
      }
    }

    // 3. Fallback standard academic classes & sections if API is empty
    if (classMap.isEmpty) {
      final defaultClasses = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cls_9', 'name': 'Class 9', 'secs': <String>['9-A', '9-B', '9-C', '9-D']},
        <String, dynamic>{'id': 'cls_10', 'name': 'Class 10', 'secs': <String>['10-A', '10-B', '10-C']},
        <String, dynamic>{'id': 'cls_11', 'name': 'Class 11', 'secs': <String>['11-A', '11-B']},
        <String, dynamic>{'id': 'cls_12', 'name': 'Class 12', 'secs': <String>['12-A', '12-B']},
      ];
      final defaultSubs = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'sub_comp', 'name': 'Computer Science'},
        <String, dynamic>{'id': 'sub_math', 'name': 'Mathematics'},
        <String, dynamic>{'id': 'sub_sci', 'name': 'Science'},
        <String, dynamic>{'id': 'sub_sst', 'name': 'Social Science'},
        <String, dynamic>{'id': 'sub_eng', 'name': 'English'},
        <String, dynamic>{'id': 'sub_phy', 'name': 'Physics'},
        <String, dynamic>{'id': 'sub_chem', 'name': 'Chemistry'},
      ];

      for (final dc in defaultClasses) {
        final cid = dc['id'] as String;
        final cname = dc['name'] as String;
        final secNames = dc['secs'] as List<String>;
        classMap[cid] = <String, dynamic>{
          'id': cid,
          'name': cname,
          'sections': secNames
              .map<Map<String, dynamic>>((sn) => <String, dynamic>{'id': 'sec_${cid}_$sn', 'name': sn})
              .toList(),
          'subjects': List<Map<String, dynamic>>.from(defaultSubs),
        };
      }
    }

    // Sort classes numerically (e.g. Class 1 -> Class 12)
    final sortedClasses = classMap.values.toList()
      ..sort((a, b) {
        final numA = int.tryParse(RegExp(r'\d+').firstMatch(a['name'] as String)?.group(0) ?? '0') ?? 0;
        final numB = int.tryParse(RegExp(r'\d+').firstMatch(b['name'] as String)?.group(0) ?? '0') ?? 0;
        if (numA != numB) return numA.compareTo(numB);
        return (a['name'] as String).compareTo(b['name'] as String);
      });

    // 1. Resolve selected Class
    if (_selectedClassId == null || !classMap.containsKey(_selectedClassId)) {
      final preferredClass = sortedClasses.firstWhere(
        (c) => (c['name'] as String).contains('10'),
        orElse: () => sortedClasses.isNotEmpty
            ? sortedClasses.first
            : <String, dynamic>{
                'id': 'cls_10',
                'name': 'Class 10',
                'sections': <Map<String, dynamic>>[],
                'subjects': <Map<String, dynamic>>[],
              },
      );
      _selectedClassId = preferredClass['id'] as String;
    }
    final currentClass = classMap[_selectedClassId] ?? (sortedClasses.isNotEmpty ? sortedClasses.first : null);
    final currentClassName = currentClass?['name'] as String? ?? 'Class 10';

    // 2. Resolve available Sections cascaded from Class
    final availableSections = List<Map<String, dynamic>>.from(
      currentClass?['sections'] as List? ?? const [],
    );
    if (availableSections.isEmpty) {
      availableSections.addAll(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'sec_${_selectedClassId}_a', 'name': '$currentClassName-A'},
        <String, dynamic>{'id': 'sec_${_selectedClassId}_b', 'name': '$currentClassName-B'},
      ]);
    }
    if (_selectedSectionId == null || !availableSections.any((s) => s['id'] == _selectedSectionId)) {
      _selectedSectionId = availableSections.isNotEmpty ? availableSections.first['id'] as String : null;
    }
    final currentSection = availableSections.firstWhere(
      (s) => s['id'] == _selectedSectionId,
      orElse: () => availableSections.isNotEmpty ? availableSections.first : <String, dynamic>{'id': 'sec_default', 'name': 'A'},
    );
    final currentSectionName = currentSection['name'] as String? ?? 'A';

    // 3. Resolve available Subjects strictly cascaded from Class & Section
    final availableSubjects = List<Map<String, dynamic>>.from(
      currentClass?['subjects'] as List? ?? const [],
    );
    if (availableSubjects.isEmpty) {
      availableSubjects.addAll(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'sub_comp', 'name': 'Computer Science'},
        <String, dynamic>{'id': 'sub_math', 'name': 'Mathematics'},
        <String, dynamic>{'id': 'sub_sci', 'name': 'Science'},
        <String, dynamic>{'id': 'sub_sst', 'name': 'Social Science'},
        <String, dynamic>{'id': 'sub_eng', 'name': 'English'},
      ]);
    }
    if (_selectedSubjectId == null || !availableSubjects.any((sub) => sub['id'] == _selectedSubjectId)) {
      _selectedSubjectId = availableSubjects.isNotEmpty ? availableSubjects.first['id'] as String : null;
    }
    final currentSubject = availableSubjects.firstWhere(
      (sub) => sub['id'] == _selectedSubjectId,
      orElse: () => availableSubjects.isNotEmpty ? availableSubjects.first : <String, dynamic>{'id': 'sub_default', 'name': 'General'},
    );
    final currentSubjectName = currentSubject['name'] as String? ?? 'General';

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 790),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload Video Recording', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 2),
                          Text('Upload and publish recorded live lectures or seminar recordings.', style: TextStyle(fontSize: 12, color: textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: cardBorder),
                const SizedBox(height: 16),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Local File Picker Dropzone Box
                        InkWell(
                          onTap: _pickLocalFile,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedFileName != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF3B82F6),
                                width: 1.5,
                              ),
                            ),
                            child: _selectedFileName != null
                                ? Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check_circle_rounded, size: 24, color: Color(0xFF10B981)),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedFileName!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${_fileSizeCtrl.text} MB • Ready to publish from local system',
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _pickLocalFile,
                                        icon: const Icon(Icons.folder_open_rounded, size: 14),
                                        label: const Text('Change File', style: TextStyle(fontSize: 11)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      const Icon(Icons.cloud_upload_rounded, size: 36, color: Color(0xFF3B82F6)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Click to browse document or video from your device',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Supported formats: MP4, WebM, MKV, PDF, DOCX, PPTX (Max 4 GB)',
                                        style: TextStyle(fontSize: 11, color: textSecondary),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text('Recording Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _titleCtrl,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter title' : null,
                          style: TextStyle(fontSize: 12.5, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'e.g. Class 10 - Conceptual Synthesis Lecture',
                            hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Cascading 3-Column Selectors: Class -> Section -> Subject
                        Row(
                          children: [
                            // 1. Class
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Class *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _selectedClassId,
                                        hint: Text('Select Class', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        isExpanded: true,
                                        compact: true,
                                        isDense: true,
                                        itemHeight: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        dropdownColor: bg,
                                        items: sortedClasses.map((cls) {
                                          return DropdownMenuItem<String>(
                                            value: cls['id'] as String,
                                            child: Text(cls['name'] as String, style: TextStyle(fontSize: 12, color: textPrimary), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null && v != _selectedClassId) {
                                            setState(() {
                                              _selectedClassId = v;
                                              final newClass = classMap[v];
                                              final newSecs = List<Map<String, dynamic>>.from(newClass?['sections'] as List? ?? const []);
                                              _selectedSectionId = newSecs.isNotEmpty ? newSecs.first['id'] as String : null;

                                              final newSubs = List<Map<String, dynamic>>.from(newClass?['subjects'] as List? ?? const []);
                                              _selectedSubjectId = newSubs.isNotEmpty ? newSubs.first['id'] as String : null;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 2. Section (Cascaded from Class)
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Section *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _selectedSectionId,
                                        hint: Text('Select Section', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        isExpanded: true,
                                        compact: true,
                                        isDense: true,
                                        itemHeight: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        dropdownColor: bg,
                                        items: availableSections.map((sec) {
                                          return DropdownMenuItem<String>(
                                            value: sec['id'] as String,
                                            child: Text(sec['name'] as String, style: TextStyle(fontSize: 12, color: textPrimary), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _selectedSectionId = v);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // 3. Subject (Cascaded from Class & Section)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Subject *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: AppSearchableDropdown<String>.fromMenuItems(
                                        value: _selectedSubjectId,
                                        hint: Text('Select Subject', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        isExpanded: true,
                                        compact: true,
                                        isDense: true,
                                        itemHeight: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        dropdownColor: bg,
                                        items: availableSubjects.map((sub) {
                                          return DropdownMenuItem<String>(
                                            value: sub['id'] as String,
                                            child: Text(sub['name'] as String, style: TextStyle(fontSize: 12, color: textPrimary), overflow: TextOverflow.ellipsis),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _selectedSubjectId = v);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Duration, File Size, Teacher Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Duration (mins)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _durationCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputFill,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('File Size (MB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _fileSizeCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputFill,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Instructor / Host', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _teacherCtrl,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: inputFill,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Visibility Options
                        Text('Audience Visibility', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildVisibilityOption('CLASS', 'Class Enrolled Only', Icons.group_rounded),
                            const SizedBox(width: 8),
                            _buildVisibilityOption('SCHOOL', 'Entire School', Icons.domain_rounded),
                            const SizedBox(width: 8),
                            _buildVisibilityOption('PRIVATE', 'Private (Teachers)', Icons.lock_outline_rounded),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Description
                        Text('Lesson Summary & Curriculum Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          style: TextStyle(fontSize: 12, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Add conceptual notes or outline for this recorded session...',
                            hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                          ),
                        ),

                        if (_isUploading) ...[
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: cardBorder,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Uploading and publishing recording to audience (${(_uploadProgress * 100).toInt()}%)...',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isUploading
                          ? null
                          : () => _handleUpload(
                                className: currentClassName,
                                sectionName: currentSectionName,
                                subjectName: currentSubjectName,
                              ),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: Text(_isUploading ? 'Uploading...' : 'Save & Publish Recording', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(String code, String label, IconData icon) {
    final isSelected = _visibility == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _visibility = code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B).withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
