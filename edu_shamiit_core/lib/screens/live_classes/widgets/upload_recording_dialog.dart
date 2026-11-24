import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_class_management_provider.dart';

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

  String _selectedClassSection = 'Class 10 - 10-A';
  String _selectedClassId = 'cls_10a';
  String _selectedSubject = 'Computer Science';
  String _selectedSubjectId = 'sub_cs';
  String _visibility = 'CLASS';
  String? _selectedFileName = 'lecture_session_recording_masterclass.mp4';
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _durationCtrl.dispose();
    _fileSizeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.15;
    });

    // Realistic upload progress simulation
    for (int i = 1; i <= 6; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _uploadProgress = (i * 0.16).clamp(0.0, 1.0);
        });
      }
    }

    final durationMin = int.tryParse(_durationCtrl.text.trim()) ?? 45;
    final sizeMb = double.tryParse(_fileSizeCtrl.text.trim()) ?? 280.0;

    final success = await ref.read(liveClassManagementProvider.notifier).uploadRecording(
      title: _titleCtrl.text.trim(),
      classId: _selectedClassId,
      classSection: _selectedClassSection,
      subjectId: _selectedSubjectId,
      subjectName: _selectedSubject,
      teacherName: _teacherCtrl.text.trim(),
      durationMinutes: durationMin,
      fileSizeMb: sizeMb,
      description: _descCtrl.text.trim(),
      visibility: _visibility,
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Recording uploaded and published to class feed successfully.' : 'Upload failed.'),
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
    final classList = meta?.classes ?? [];
    final subjectList = meta?.subjects ?? [];

    final combinedClasses = <String>{
      'Class 10 - 10-A',
      'Class 10 - 10-B',
      'Class 11 - 11-A',
      'Class 12 - 12-A',
      ...classList.map((c) => c.name.trim()).where((n) => n.isNotEmpty),
      if (_selectedClassSection.trim().isNotEmpty) _selectedClassSection.trim(),
    }.toList();

    final effectiveClass = combinedClasses.contains(_selectedClassSection)
        ? _selectedClassSection
        : (combinedClasses.isNotEmpty ? combinedClasses.first : null);

    final combinedSubjects = <String>{
      'Computer Science',
      'Mathematics',
      'Physics',
      'Chemistry',
      'General',
      ...subjectList.map((s) => s.name.trim()).where((n) => n.isNotEmpty),
      if (_selectedSubject.trim().isNotEmpty) _selectedSubject.trim(),
    }.toList();

    final effectiveSubject = combinedSubjects.contains(_selectedSubject)
        ? _selectedSubject
        : (combinedSubjects.isNotEmpty ? combinedSubjects.first : null);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
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
                        // Dropzone box
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFileName = 'recorded_lecture_${DateTime.now().millisecondsSinceEpoch % 10000}.mp4';
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.video_file_rounded, size: 36, color: Color(0xFF3B82F6)),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFileName ?? 'Drop video file here or click to browse',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedFileName != null ? const Color(0xFF10B981) : textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Supported formats: MP4, WebM, MKV (Max 4 GB)', style: TextStyle(fontSize: 11, color: textSecondary)),
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
                            hintText: 'e.g. Class 10 - Computer Science Algorithm Design',
                            hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Class & Subject Row
                        Row(
                          children: [
                            // Class
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Class & Section *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: effectiveClass,
                                        hint: Text('Select Class', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        isExpanded: true,
                                        dropdownColor: bg,
                                        items: combinedClasses.map((cls) {
                                          return DropdownMenuItem<String>(
                                            value: cls,
                                            child: Text(cls, style: TextStyle(fontSize: 12, color: textPrimary)),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _selectedClassSection = v;
                                              final match = classList.where((c) => c.name == v).firstOrNull;
                                              if (match != null) _selectedClassId = match.id;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Subject
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Subject *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: inputFill,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: effectiveSubject,
                                        hint: Text('Select Subject', style: TextStyle(fontSize: 12, color: textSecondary)),
                                        isExpanded: true,
                                        dropdownColor: bg,
                                        items: combinedSubjects.map((sub) {
                                          return DropdownMenuItem<String>(
                                            value: sub,
                                            child: Text(sub, style: TextStyle(fontSize: 12, color: textPrimary)),
                                          );
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() {
                                              _selectedSubject = v;
                                              final match = subjectList.where((s) => s.name == v).firstOrNull;
                                              if (match != null) _selectedSubjectId = match.id;
                                            });
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
                            'Uploading and processing high-definition recording (${(_uploadProgress * 100).toInt()}%)...',
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
                      onPressed: _isUploading ? null : _handleUpload,
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
