import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/core/file_download_helper.dart';
import 'assign_employees_dialog.dart';
import 'add_session_dialog.dart';
import 'record_attendance_dialog.dart';

class TrainingDetailDrawer extends StatefulWidget {
  final String programId;
  final VoidCallback onProgramUpdated;

  const TrainingDetailDrawer({
    super.key,
    required this.programId,
    required this.onProgramUpdated,
  });

  @override
  State<TrainingDetailDrawer> createState() => _TrainingDetailDrawerState();
}

class _TrainingDetailDrawerState extends State<TrainingDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic>? _programData;
  List<dynamic> _participants = [];
  List<dynamic> _sessions = [];
  List<dynamic> _materials = [];
  List<dynamic> _certificates = [];
  List<dynamic> _feedbackList = [];
  Map<String, dynamic> _feedbackStats = {};
  List<dynamic> _activityLogs = [];

  final Set<String> _selectedEligibleEmpIds = {};
  bool _isGeneratingCertificates = false;

  String _participantSearch = '';

  final List<String> _tabs = [
    'Overview',
    'Participants',
    'Sessions',
    'Materials',
    'Attendance',
    'Assessment',
    'Certificates',
    'Feedback',
    'Activity',
  ];

  final List<String> _availableStatuses = [
    'DRAFT',
    'SCHEDULED',
    'UPCOMING',
    'IN_PROGRESS',
    'COMPLETED',
    'ARCHIVED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _fetchDetails();
  }

  @override
  void didUpdateWidget(covariant TrainingDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.programId != widget.programId) {
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/training/programs/${widget.programId}', useCache: false);
      if (res['success'] == true) {
        _programData = res['data'] as Map<String, dynamic>;
        _sessions = (_programData?['sessions'] as List<dynamic>?) ?? [];
        _materials = (_programData?['materials'] as List<dynamic>?) ?? [];
      }

      final partRes = await _api.get('/training/programs/${widget.programId}/participants', useCache: false);
      if (partRes['success'] == true) {
        _participants = (partRes['data'] as List<dynamic>?) ?? [];
      }

      final certRes = await _api.get('/training/certificates?program_id=${widget.programId}', useCache: false);
      if (certRes['success'] == true) {
        _certificates = (certRes['data'] as List<dynamic>?) ?? [];
      }

      final fbRes = await _api.get('/training/programs/${widget.programId}/feedback', useCache: false);
      if (fbRes['success'] == true && fbRes['data'] is Map) {
        _feedbackStats = fbRes['data'] as Map<String, dynamic>;
        _feedbackList = (_feedbackStats['reviews'] as List<dynamic>?) ?? [];
      }

      final actRes = await _api.get('/training/programs/${widget.programId}/activity', useCache: false);
      if (actRes['success'] == true && actRes['data'] is List) {
        _activityLogs = actRes['data'] as List<dynamic>;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // STATUS CHANGE ACTION
  // =========================================================================
  Future<void> _changeProgramStatus(String newStatus) async {
    try {
      final res = await _api.patch('/training/programs/${widget.programId}/status', {
        'status': newStatus,
      });

      if (res['success'] == true) {
        setState(() {
          if (_programData != null) {
            _programData!['status'] = newStatus;
          }
        });
        widget.onProgramUpdated();
        _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Training program status updated to $newStatus!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // =========================================================================
  // PARTICIPANTS ACTIONS
  // =========================================================================
  Future<void> _removeParticipant(String enrollmentId) async {
    try {
      final res = await _api.delete('/training/programs/${widget.programId}/participants/$enrollmentId');
      if (res['success'] == true) {
        _fetchDetails();
        widget.onProgramUpdated();
      }
    } catch (_) {}
  }

  Future<void> _issueCertificate(String employeeId) async {
    try {
      final res = await _api.post('/training/certificates/generate', {
        'program_id': widget.programId,
        'employee_id': employeeId,
        'validity_months': 12,
      });
      if (res['success'] == true) {
        _selectedEligibleEmpIds.remove(employeeId);
        _fetchDetails();
        widget.onProgramUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Certificate issued successfully!'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error issuing certificate: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateCertificatesForSelected(List<String> employeeIds) async {
    if (employeeIds.isEmpty) return;
    setState(() => _isGeneratingCertificates = true);
    final messenger = ScaffoldMessenger.of(context);
    int issued = 0;
    try {
      for (final empId in employeeIds) {
        final res = await _api.post('/training/certificates/generate', {
          'program_id': widget.programId,
          'employee_id': empId,
          'validity_months': 12,
        });
        if (res['success'] == true) {
          issued++;
        }
      }
      _selectedEligibleEmpIds.clear();
      _fetchDetails();
      widget.onProgramUpdated();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(issued > 0 ? 'Issued $issued completion certificates!' : 'No certificates issued.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error generating certificates: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingCertificates = false);
    }
  }

  Future<void> _generateAllCertificates() async {
    final eligible = _participants.where((p) {
      final stat = (p['status'] ?? '').toString().toUpperCase();
      final aStat = (p['assessment_status'] ?? '').toString().toUpperCase();
      final score = p['assessment_score'];
      final hasCert = _certificates.any((c) =>
          c['employee_id'] == p['employee_id'] && (c['status'] ?? '').toString().toUpperCase() == 'VALID');
      return (stat == 'COMPLETED' || aStat == 'PASSED' || (score != null && (score as num) >= 70)) && !hasCert;
    }).map((p) => p['employee_id'].toString()).toList();

    if (eligible.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new eligible participants found for certificates.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    await _generateCertificatesForSelected(eligible);
  }

  // =========================================================================
  // MATERIALS ACTIONS
  // =========================================================================
  void _openAddMaterialDialog() {
    final titleCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    String matType = 'PDF';
    bool isFileUploadMode = true;
    Uint8List? selectedFileBytes;
    String? selectedFileName;
    int? selectedFileSizeBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          String formatBytes(int bytes) {
            if (bytes < 1024) return '$bytes B';
            if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
            return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Add Course Material', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Selector: Upload File vs Cloud Link
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isUploading ? null : () => setDlgState(() => isFileUploadMode = true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isFileUploadMode ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: isFileUploadMode
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open_rounded, size: 16, color: isFileUploadMode ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Upload from Computer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isFileUploadMode ? FontWeight.bold : FontWeight.normal,
                                        color: isFileUploadMode ? const Color(0xFF4F46E5) : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: isUploading ? null : () => setDlgState(() => isFileUploadMode = false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isFileUploadMode ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: !isFileUploadMode
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.link_rounded, size: 16, color: !isFileUploadMode ? const Color(0xFF4F46E5) : Colors.grey.shade600),
                                    const SizedBox(width: 6),
                                    Text(
                                      'External Link / URL',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: !isFileUploadMode ? FontWeight.bold : FontWeight.normal,
                                        color: !isFileUploadMode ? const Color(0xFF4F46E5) : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isFileUploadMode) ...[
                      // File Picker Area
                      if (selectedFileBytes == null)
                        InkWell(
                          onTap: isUploading
                              ? null
                              : () async {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'doc',
                                      'docx',
                                      'ppt',
                                      'pptx',
                                      'xls',
                                      'xlsx',
                                      'mp4',
                                      'txt',
                                      'zip',
                                      'png',
                                      'jpg',
                                      'jpeg',
                                    ],
                                    withData: true,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    final file = result.files.first;
                                    setDlgState(() {
                                      selectedFileBytes = file.bytes;
                                      selectedFileName = file.name;
                                      selectedFileSizeBytes = file.size;
                                      if (titleCtrl.text.trim().isEmpty) {
                                        final rawName = file.name.contains('.')
                                            ? file.name.substring(0, file.name.lastIndexOf('.'))
                                            : file.name;
                                        titleCtrl.text = rawName.replaceAll('_', ' ').replaceAll('-', ' ');
                                      }
                                      final ext = (file.extension ?? '').toLowerCase();
                                      if (['pdf'].contains(ext)) {
                                        matType = 'PDF';
                                      } else if (['doc', 'docx', 'txt', 'rtf'].contains(ext)) {
                                        matType = 'Document';
                                      } else if (['ppt', 'pptx'].contains(ext)) {
                                        matType = 'Slides';
                                      } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
                                        matType = 'Spreadsheet';
                                      } else if (['mp4', 'mov', 'avi'].contains(ext)) {
                                        matType = 'Video';
                                      }
                                    });
                                  }
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF4F46E5)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Choose a document from your computer',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF4F46E5)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF, Word, Slides, Excel, Video (Up to 50 MB)',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedFileName ?? 'Selected File',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatBytes(selectedFileSizeBytes ?? 0),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isUploading)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                  tooltip: 'Remove selected file',
                                  onPressed: () {
                                    setDlgState(() {
                                      selectedFileBytes = null;
                                      selectedFileName = null;
                                      selectedFileSizeBytes = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),
                    ] else ...[
                      // External Link Field
                      TextField(
                        controller: linkCtrl,
                        enabled: !isUploading,
                        decoration: const InputDecoration(
                          labelText: 'Document URL or Cloud Link *',
                          hintText: 'https://drive.google.com/... or https://...',
                          prefixIcon: Icon(Icons.link, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextField(
                      controller: titleCtrl,
                      enabled: !isUploading,
                      decoration: const InputDecoration(
                        labelText: 'Material Title *',
                        hintText: 'e.g. Workshop Handout & Syllabus',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: matType,
                      decoration: const InputDecoration(
                        labelText: 'Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['PDF', 'Document', 'Slides', 'Spreadsheet', 'Video', 'Link']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: isUploading ? null : (v) => setDlgState(() => matType = v ?? 'PDF'),
                    ),

                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Uploading material to server...', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide a material title.'), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);

                        if (isFileUploadMode) {
                          if (selectedFileBytes == null) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please select a file from your computer.'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          setDlgState(() => isUploading = true);
                          try {
                            final uri = Uri.parse('${AppConfig.apiBaseUrl}/training/programs/${widget.programId}/materials/upload');
                            final req = http.MultipartRequest('POST', uri);
                            final prefs = await SharedPreferences.getInstance();
                            final token = prefs.getString('auth_token') ?? prefs.getString('token');
                            final schoolId = prefs.getString('school_id') ?? prefs.getString('current_school_id');
                            if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
                            if (schoolId != null && schoolId.isNotEmpty) req.headers['X-School-Id'] = schoolId;

                            req.fields['title'] = title;
                            req.fields['material_type'] = matType;
                            req.files.add(http.MultipartFile.fromBytes(
                              'file',
                              selectedFileBytes!,
                              filename: selectedFileName ?? 'material.pdf',
                            ));

                            final streamed = await req.send();
                            final resp = await http.Response.fromStream(streamed);

                            if (resp.statusCode >= 200 && resp.statusCode < 300) {
                              nav.pop();
                              _fetchDetails();
                              widget.onProgramUpdated();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Uploaded "$title" successfully!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            } else {
                              throw Exception('Upload failed (${resp.statusCode}): ${resp.body}');
                            }
                          } catch (e) {
                            setDlgState(() => isUploading = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } else {
                          final link = linkCtrl.text.trim();
                          if (link.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please provide an external link/URL.'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          setDlgState(() => isUploading = true);
                          try {
                            await _api.post('/training/programs/${widget.programId}/materials', {
                              'title': title,
                              'material_type': matType,
                              'external_link': link,
                              'file_size_display': matType == 'Video' ? 'Cloud Video' : 'External Link',
                            });
                            nav.pop();
                            _fetchDetails();
                            widget.onProgramUpdated();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Added material "$title"!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          } catch (e) {
                            setDlgState(() => isUploading = false);
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                child: isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Material', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _downloadOrOpenMaterial(Map<String, dynamic> m) async {
    final mid = m['id'].toString();
    final title = m['title'] ?? 'Material';
    final type = m['material_type'] ?? 'Document';
    final link = (m['external_link'] ?? m['file_url'] ?? '').toString();
    final messenger = ScaffoldMessenger.of(context);

    if (link.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No download link or file available for this material.'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      if (link.startsWith('http://') || link.startsWith('https://')) {
        // External link
        final uri = Uri.parse(link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text('Opening link: $link'), backgroundColor: const Color(0xFF4F46E5)),
          );
        }
      } else {
        // Backend file download
        final downloadUrl = link.startsWith('/api/')
            ? '${AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '')}$link'
            : '${AppConfig.apiBaseUrl}/training/programs/${widget.programId}/materials/$mid/download';

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? prefs.getString('token');
        final schoolId = prefs.getString('school_id') ?? prefs.getString('current_school_id');
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
        if (schoolId != null && schoolId.isNotEmpty) headers['X-School-Id'] = schoolId;

        messenger.showSnackBar(
          SnackBar(content: Text('Downloading "$title"...'), duration: const Duration(seconds: 1)),
        );

        final res = await http.get(Uri.parse(downloadUrl), headers: headers);
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final ext = type == 'PDF' ? 'pdf' : (type == 'Video' ? 'mp4' : (type == 'Slides' ? 'pptx' : (type == 'Spreadsheet' ? 'xlsx' : 'bin')));
          final fileName = title.contains('.') ? title : '$title.$ext';
          downloadBytes(res.bodyBytes, fileName);
          messenger.showSnackBar(
            SnackBar(content: Text('Downloaded "$fileName" successfully!'), backgroundColor: const Color(0xFF10B981)),
          );
        } else {
          throw Exception('Server returned status ${res.statusCode}');
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to download material: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMaterial(String matId) async {
    try {
      await _api.delete('/training/programs/${widget.programId}/materials/$matId');
      _fetchDetails();
      widget.onProgramUpdated();
    } catch (_) {}
  }

  // =========================================================================
  // ASSESSMENT SCORE DIALOG
  // =========================================================================
  // ASSESSMENT ACTIONS & DIALOGS
  // =========================================================================
  void _openRecordScoreDialog(Map<String, dynamic> participant) {
    final enrId = participant['enrollment_id'].toString();
    final name = participant['employee_name'] ?? 'Staff Member';
    final passingScore = (_programData?['passing_score'] as num?)?.toDouble() ?? 70.0;
    final initialScore = (participant['assessment_score'] as num?)?.toDouble() ?? passingScore;
    final scoreCtrl = TextEditingController(text: '${initialScore.round()}');
    final remarksCtrl = TextEditingController();
    String outcome = (participant['assessment_status'] ?? (initialScore >= passingScore ? 'PASSED' : 'FAILED')).toString().toUpperCase();
    if (!['PASSED', 'FAILED', 'PENDING'].contains(outcome)) outcome = 'PASSED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Record Assessment Score: $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: ['PASSED', 'FAILED', 'PENDING'].map((opt) {
                  final isSel = outcome == opt;
                  Color col = const Color(0xFF10B981);
                  if (opt == 'FAILED') col = Colors.red;
                  if (opt == 'PENDING') col = const Color(0xFFF59E0B);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setDlgState(() => outcome = opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? col.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? col : Colors.grey.shade300, width: isSel ? 2 : 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(opt, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? col : null)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Score Achieved (0 - 100) *',
                  helperText: 'Passing Threshold: >= ${passingScore.round()}%',
                  suffixText: '%',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (val) {
                  final s = double.tryParse(val.trim());
                  if (s != null) {
                    setDlgState(() {
                      outcome = s >= passingScore ? 'PASSED' : 'FAILED';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Evaluator Remarks', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final score = double.tryParse(scoreCtrl.text.trim()) ?? passingScore;
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                try {
                  final res = await _api.post('/training/programs/${widget.programId}/participants/$enrId/assessment', {
                    'score': score,
                    'status': outcome,
                    'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                  });
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchDetails();
                    widget.onProgramUpdated();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Assessment recorded for $name ($outcome: ${score.round()}%)!'), backgroundColor: const Color(0xFF10B981)),
                    );
                  } else {
                    throw Exception(res['message'] ?? 'Failed to record assessment');
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error saving score: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Save Score', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openConfigureAssessmentDialog() {
    String selectedType = _programData?['assessment_type'] ?? 'Quiz';
    final scoreCtrl = TextEditingController(text: '${(_programData?['passing_score'] ?? 70).round()}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Configure Assessment Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: ['Quiz', 'Exam', 'Practical Evaluation', 'Project', 'Assignment', 'None'].contains(selectedType)
                    ? selectedType
                    : 'Quiz',
                decoration: const InputDecoration(labelText: 'Assessment Type *', border: OutlineInputBorder()),
                items: ['Quiz', 'Exam', 'Practical Evaluation', 'Project', 'Assignment', 'None']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setDlgState(() => selectedType = v ?? 'Quiz'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Passing Score Threshold (0 - 100) *',
                  hintText: '70',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final score = double.tryParse(scoreCtrl.text.trim()) ?? 70.0;
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                try {
                  await _api.put('/training/programs/${widget.programId}', {
                    'assessment_type': selectedType,
                    'passing_score': score,
                  });
                  nav.pop();
                  _fetchDetails();
                  widget.onProgramUpdated();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Assessment settings updated!'), backgroundColor: Color(0xFF10B981)),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Save Settings', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openBulkEvaluateDialog() {
    String bulkStatus = 'PASSED';
    final passingScore = (_programData?['passing_score'] as num?)?.toDouble() ?? 70.0;
    final scoreCtrl = TextEditingController(text: '${passingScore.round()}');
    final remarksCtrl = TextEditingController(text: 'Completed program assessment requirements.');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Bulk Evaluate Participants'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply assessment score and outcome to all enrolled participants:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              Row(
                children: ['PASSED', 'FAILED', 'PENDING'].map((opt) {
                  final isSel = bulkStatus == opt;
                  Color col = const Color(0xFF10B981);
                  if (opt == 'FAILED') col = Colors.red;
                  if (opt == 'PENDING') col = const Color(0xFFF59E0B);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setDlgState(() => bulkStatus = opt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel ? col.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? col : Colors.grey.shade300, width: isSel ? 2 : 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(opt, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? col : null)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: scoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default Score (0 - 100) *',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Evaluation Remarks',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final score = double.tryParse(scoreCtrl.text.trim()) ?? passingScore;
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);
                try {
                  await _api.post('/training/programs/${widget.programId}/assessment/bulk', {
                    'status': bulkStatus,
                    'score': score,
                    'remarks': remarksCtrl.text.trim(),
                  });
                  nav.pop();
                  _fetchDetails();
                  widget.onProgramUpdated();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Bulk evaluated all participants as $bulkStatus ($score%)!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Apply to All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // CERTIFICATE ACTIONS & PDF DOWNLOAD
  // =========================================================================
  Future<void> _downloadCertificatePdf(Map<String, dynamic> c) async {
    final cid = c['id'].toString();
    final certNo = c['certificate_number'] ?? 'CERT';
    final empName = c['employee_name'] ?? 'Staff';
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(content: Text('Generating official certificate PDF for $empName...'), duration: const Duration(seconds: 1)),
    );

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/training/certificates/$cid/pdf');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? prefs.getString('token');
      final schoolId = prefs.getString('school_id') ?? prefs.getString('current_school_id');
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      if (schoolId != null && schoolId.isNotEmpty) headers['X-School-Id'] = schoolId;

      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final safeName = empName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final fileName = 'Certificate_${certNo}_$safeName.pdf';
        downloadBytes(res.bodyBytes, fileName, mimeType: 'application/pdf');
        messenger.showSnackBar(
          SnackBar(content: Text('Downloaded certificate PDF: $fileName!'), backgroundColor: const Color(0xFF10B981)),
        );
      } else {
        throw Exception('Server returned status ${res.statusCode}');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error downloading certificate: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _previewCertificateDialog(Map<String, dynamic> c) {
    final certNo = c['certificate_number'] ?? 'CERT-TRN-001';
    final empName = c['employee_name'] ?? 'Staff Member';
    final issueDate = c['issue_date'] ?? '';
    final expiryDate = c['expiry_date'] ?? 'Permanent';
    final progTitle = _programData?['title'] ?? 'Training Program';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        content: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD97706), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'EDUSHAMIIT INTERNATIONAL SCHOOL',
                style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 6),
              const Text(
                'CERTIFICATE OF COMPLETION',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B), letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              const Text('This is proudly presented to', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(empName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              const Divider(color: Color(0xFFD97706), thickness: 1, indent: 40, endIndent: 40),
              const SizedBox(height: 6),
              const Text('for successfully completing all coursework and evaluations for:', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
              const SizedBox(height: 4),
              Text('"$progTitle"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cert ID: $certNo', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('Issued: $issueDate', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('Validity: $expiryDate', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      border: Border.all(color: const Color(0xFFD97706)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('★ VERIFIED OFFICIAL ★', style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadCertificatePdf(c);
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download Official PDF', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeCertificate(String cid, String certNo, String empName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Certificate?'),
        content: Text('Are you sure you want to revoke certificate $certNo issued to $empName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _api.post('/training/certificates/$cid/revoke', {});
        _fetchDetails();
        widget.onProgramUpdated();
        messenger.showSnackBar(
          SnackBar(content: Text('Certificate $certNo revoked!'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error revoking certificate: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // =========================================================================
  // SUBMIT FEEDBACK DIALOG
  // =========================================================================
  void _openSubmitFeedbackDialog() {
    int rating = 5;
    int trainerRating = 5;
    int contentRating = 5;
    final textCtrl = TextEditingController();
    String selectedParticipantName = _participants.isNotEmpty
        ? (_participants.first['employee_name'] ?? 'Staff Member')
        : 'Senior Faculty Member';
    final customNameCtrl = TextEditingController();
    bool isCustomName = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Submit Participant Feedback'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_participants.isNotEmpty && !isCustomName) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedParticipantName,
                      decoration: const InputDecoration(labelText: 'Reviewer (Enrolled Participant) *', border: OutlineInputBorder()),
                      items: _participants.map<DropdownMenuItem<String>>((p) {
                        final n = (p['employee_name'] ?? 'Staff Member').toString();
                        return DropdownMenuItem(value: n, child: Text(n));
                      }).toList(),
                      onChanged: (v) => setDlgState(() => selectedParticipantName = v ?? selectedParticipantName),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setDlgState(() => isCustomName = true),
                        child: const Text('Or enter custom name', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: customNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reviewer Name *',
                        hintText: 'e.g. Dr. Jane Smith',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_participants.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setDlgState(() => isCustomName = false),
                          child: const Text('Choose from enrolled participants', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                  ],
                  const SizedBox(height: 10),
                  const Text('Overall Program Rating:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: List.generate(5, (idx) {
                      final star = idx + 1;
                      return IconButton(
                        icon: Icon(star <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF59E0B)),
                        onPressed: () => setDlgState(() => rating = star),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text('Trainer Effectiveness:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: List.generate(5, (idx) {
                      final star = idx + 1;
                      return IconButton(
                        icon: Icon(star <= trainerRating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF59E0B)),
                        onPressed: () => setDlgState(() => trainerRating = star),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  const Text('Course Content Quality:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Row(
                    children: List.generate(5, (idx) {
                      final star = idx + 1;
                      return IconButton(
                        icon: Icon(star <= contentRating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFF59E0B)),
                        onPressed: () => setDlgState(() => contentRating = star),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comments / Review *',
                      hintText: 'Share key takeaways, course highlights, and feedback...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final empName = isCustomName || _participants.isEmpty
                    ? (customNameCtrl.text.trim().isNotEmpty ? customNameCtrl.text.trim() : 'Staff Member')
                    : selectedParticipantName;
                final text = textCtrl.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);

                try {
                  final res = await _api.post('/training/programs/${widget.programId}/feedback', {
                    'program_id': widget.programId,
                    'rating': rating,
                    'trainer_rating': trainerRating,
                    'content_rating': contentRating,
                    'feedback_text': text.isNotEmpty ? text : 'Great training session with actionable insights.',
                    'employee_name': empName,
                  });

                  if (res['success'] == true) {
                    nav.pop();
                    _fetchDetails();
                    widget.onProgramUpdated();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Feedback submitted for $empName!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  } else {
                    throw Exception(res['message'] ?? 'Failed to submit feedback');
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              child: const Text('Submit Review', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
      ),
      child: Container(
        width: 880,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _programData == null
                ? const Center(child: Text('Failed to load training details.'))
                : Column(
                    children: [
                      // Header Section with Interactive Status Dropdown
                      _buildHeader(isDark),
                      const Divider(height: 1),

                      // Tabs Bar
                      Container(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          labelColor: const Color(0xFF4F46E5),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: const Color(0xFF4F46E5),
                          indicatorWeight: 3,
                          tabs: _tabs.map((t) => Tab(text: t)).toList(),
                        ),
                      ),
                      const Divider(height: 1),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOverviewTab(isDark),
                            _buildParticipantsTab(isDark),
                            _buildSessionsTab(isDark),
                            _buildMaterialsTab(isDark),
                            _buildAttendanceTab(isDark),
                            _buildAssessmentTab(isDark),
                            _buildCertificatesTab(isDark),
                            _buildFeedbackTab(isDark),
                            _buildActivityTab(isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // =========================================================================
  // HEADER WITH STATUS PICKER
  // =========================================================================
  Widget _buildHeader(bool isDark) {
    final title = _programData?['title'] ?? 'Training Program';
    final code = _programData?['program_code'] ?? 'TRN';
    final cat = _programData?['category_name'] ?? 'Professional Development';
    final isMandatory = _programData?['is_mandatory'] ?? false;
    final stat = (_programData?['status'] ?? 'UPCOMING').toString().toUpperCase();

    Color statColor = const Color(0xFF4F46E5);
    if (stat == 'COMPLETED') statColor = const Color(0xFF10B981);
    if (stat == 'IN_PROGRESS') statColor = const Color(0xFF0284C7);
    if (stat == 'UPCOMING' || stat == 'SCHEDULED') statColor = const Color(0xFFF59E0B);
    if (stat == 'CANCELLED' || stat == 'ARCHIVED') statColor = Colors.grey;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_outlined, color: Color(0xFF4F46E5), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Interactive Status Dropdown Button
                          PopupMenuButton<String>(
                            tooltip: 'Change Program Status',
                            onSelected: _changeProgramStatus,
                            itemBuilder: (_) => _availableStatuses.map((s) {
                              Color c = const Color(0xFF4F46E5);
                              if (s == 'COMPLETED') c = const Color(0xFF10B981);
                              if (s == 'IN_PROGRESS') c = const Color(0xFF0284C7);
                              if (s == 'UPCOMING' || s == 'SCHEDULED') c = const Color(0xFFF59E0B);
                              if (s == 'CANCELLED' || s == 'ARCHIVED') c = Colors.grey;

                              return PopupMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.replaceAll('_', ' '),
                                      style: TextStyle(fontWeight: s == stat ? FontWeight.bold : FontWeight.normal),
                                    ),
                                    if (s == stat) ...[
                                      const Spacer(),
                                      const Icon(Icons.check, size: 16, color: Color(0xFF10B981)),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: statColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    stat.replaceAll('_', ' '),
                                    style: TextStyle(color: statColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, size: 16, color: statColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5))),
                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                          Text(cat, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if (isMandatory) ...[
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('MANDATORY', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW
  // =========================================================================
  Widget _buildOverviewTab(bool isDark) {
    final p = _programData ?? {};
    final desc = p['description'] ?? 'No detailed description provided.';
    final trainer = p['trainer_name'] ?? 'Faculty Lead';
    final provider = p['provider_name'] ?? 'Greenfield Academy';
    final mode = p['mode'] ?? 'Offline';
    final location = p['location_or_link'] ?? 'Main Campus';
    final duration = p['duration_display'] ?? '2 Hours';
    final capacity = p['capacity'] ?? 30;
    final enrolled = p['enrolled_count'] ?? _participants.length;
    final completed = p['completed_count'] ?? 0;
    final completionRate = p['completion_rate'] ?? 0.0;
    final budget = p['budget_cost'] ?? 0;
    final stat = (p['status'] ?? 'UPCOMING').toString().toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Lifecycle Status Controls Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.published_with_changes_rounded, size: 18, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 10),
                    Text('Current Status: $stat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (stat == 'DRAFT' || stat == 'SCHEDULED')
                      ElevatedButton.icon(
                        onPressed: () => _changeProgramStatus('UPCOMING'),
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text('Publish Program', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                    if (stat == 'UPCOMING' || stat == 'SCHEDULED')
                      ElevatedButton.icon(
                        onPressed: () => _changeProgramStatus('IN_PROGRESS'),
                        icon: const Icon(Icons.play_arrow_rounded, size: 14),
                        label: const Text('Start Training', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                    if (stat == 'IN_PROGRESS')
                      ElevatedButton.icon(
                        onPressed: () => _changeProgramStatus('COMPLETED'),
                        icon: const Icon(Icons.check_circle_outline, size: 14),
                        label: const Text('Complete Training', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                    OutlinedButton(
                      onPressed: () => _changeProgramStatus(stat == 'ARCHIVED' ? 'UPCOMING' : 'ARCHIVED'),
                      child: Text(stat == 'ARCHIVED' ? 'Unarchive' : 'Archive', style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Course Overview & Syllabus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Key Metrics Grid
          Row(
            children: [
              _buildOverviewCard('Enrolled Staff', '$enrolled', Icons.people_outline, const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Completed', '$completed', Icons.task_alt_outlined, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Completion Rate', '$completionRate%', Icons.trending_up, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Training Budget', '₹$budget', Icons.account_balance_wallet_outlined, const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Meta Details Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Trainer / Instructor', trainer),
                _buildDetailRow('Provider Agency', provider),
                _buildDetailRow('Mode & Location', '$mode ($location)'),
                _buildDetailRow('Duration & Capacity', '$duration • Max $capacity Seats'),
                _buildDetailRow('Assessment Method', p['assessment_type'] ?? 'Quiz'),
                _buildDetailRow('Certificate Validity', '${p['certificate_validity_type'] ?? 'Permanent'} (${p['certificate_validity_months'] ?? 12} Months)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(icon, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: PARTICIPANTS
  // =========================================================================
  Widget _buildParticipantsTab(bool isDark) {
    final filtered = _participants.where((p) {
      final name = (p['employee_name'] ?? '').toString().toLowerCase();
      final code = (p['employee_code'] ?? '').toString().toLowerCase();
      final q = _participantSearch.toLowerCase();
      return _participantSearch.isEmpty || name.contains(q) || code.contains(q);
    }).toList();

    return Column(
      children: [
        // Action Bar & Search
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search participants...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _participantSearch = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AssignEmployeesDialog(
                      programId: widget.programId,
                      programTitle: _programData?['title'] ?? 'Training',
                      onAssigned: () {
                        _fetchDetails();
                        widget.onProgramUpdated();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign Employees'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No employees assigned to this training yet.'))
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final eid = p['enrollment_id'].toString();
                    final empId = p['employee_id'].toString();
                    final name = p['employee_name'] ?? 'Staff Member';
                    final code = p['employee_code'] ?? 'Emp--';
                    final dept = p['department'] ?? 'Academics';
                    final stat = (p['status'] ?? 'ASSIGNED').toString().toUpperCase();
                    final progress = (p['progress_percentage'] ?? 0).toDouble();
                    final certStatus = p['certificate_status'] ?? 'NOT_ISSUED';
                    final score = p['assessment_score'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        child: Text(name.isNotEmpty ? name[0] : 'E', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      ),
                      title: Row(
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: stat == 'COMPLETED' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(stat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stat == 'COMPLETED' ? const Color(0xFF10B981) : const Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$code • $dept • Score: ${score != null ? '$score%' : 'Pending'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: progress / 100, minHeight: 4, color: const Color(0xFF4F46E5)),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.grading_rounded, size: 20, color: Color(0xFF4F46E5)),
                            tooltip: 'Record Assessment Score',
                            onPressed: () => _openRecordScoreDialog(p),
                          ),
                          if (certStatus != 'ISSUED')
                            IconButton(
                              icon: const Icon(Icons.workspace_premium_outlined, size: 20, color: Color(0xFF10B981)),
                              tooltip: 'Issue Certificate',
                              onPressed: () => _issueCertificate(empId),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            tooltip: 'Remove Participant',
                            onPressed: () => _removeParticipant(eid),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: SESSIONS
  // =========================================================================
  Widget _buildSessionsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_sessions.length} Scheduled Sessions', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddSessionDialog(
                      programId: widget.programId,
                      programTitle: _programData?['title'] ?? 'Training',
                      onSessionAdded: () {
                        _fetchDetails();
                        widget.onProgramUpdated();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Session'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _sessions.isEmpty
              ? const Center(child: Text('No sessions scheduled yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    final sid = s['id'].toString();
                    final title = s['session_title'] ?? 'Session';
                    final date = s['session_date'] ?? '';
                    final time = '${s['start_time'] ?? ''} - ${s['end_time'] ?? ''}';
                    final trainer = s['trainer_name'] ?? 'Trainer Lead';
                    final mode = s['mode'] ?? 'Offline';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, color: Color(0xFF4F46E5), size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('$date • $time • Mode: $mode • Trainer: $trainer', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => RecordAttendanceDialog(
                                  sessionId: sid,
                                  sessionTitle: title,
                                  sessionDate: date,
                                  sessionTime: time,
                                  onAttendanceSaved: () {
                                    _fetchDetails();
                                    widget.onProgramUpdated();
                                  },
                                ),
                              );
                            },
                            icon: const Icon(Icons.how_to_reg_outlined, size: 14),
                            label: const Text('Attendance', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: MATERIALS
  // =========================================================================
  Widget _buildMaterialsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_materials.length} Course Materials', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _openAddMaterialDialog,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Add Material'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No course materials uploaded yet.'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _openAddMaterialDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Upload Handout or Syllabus'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _materials.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final m = _materials[i];
                    final mid = m['id'].toString();
                    final title = m['title'] ?? 'Training Material';
                    final type = m['material_type'] ?? 'Document';
                    final size = m['file_size_display'] ?? '2.4 MB';

                    IconData ic = Icons.picture_as_pdf_outlined;
                    Color col = Colors.red;
                    if (type == 'Video') {
                      ic = Icons.play_circle_outline;
                      col = const Color(0xFF0284C7);
                    } else if (type == 'Slides') {
                      ic = Icons.slideshow_rounded;
                      col = const Color(0xFFF59E0B);
                    } else if (type == 'Link') {
                      ic = Icons.link_rounded;
                      col = const Color(0xFF10B981);
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(ic, color: col, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('$type • $size', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, size: 18),
                            tooltip: 'Download / Open Material',
                            onPressed: () => _downloadOrOpenMaterial(m),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete Material',
                            onPressed: () => _deleteMaterial(mid),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 5: ATTENDANCE
  // =========================================================================
  Widget _buildAttendanceTab(bool isDark) {
    final attSummary = _programData?['attendance_summary'] as Map<String, dynamic>?;
    final bool hasRecords = attSummary?['has_records'] == true;
    final num compRate = (attSummary?['compliance_rate'] as num?) ?? 0;
    final num absRate = (attSummary?['absence_rate'] as num?) ?? 0;
    final int presentCount = (attSummary?['present_count'] as num?)?.toInt() ?? 0;
    final String complianceRateStr = hasRecords ? '${compRate.toStringAsFixed(compRate.truncateToDouble() == compRate ? 0 : 1)}%' : '0%';
    final String absenceRateStr = hasRecords ? '${absRate.toStringAsFixed(absRate.truncateToDouble() == absRate ? 0 : 1)}%' : '0%';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attendance Summary Cards
          Row(
            children: [
              _buildOverviewCard('Total Sessions', '${_sessions.length}', Icons.event_available_rounded, const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Attendance Compliance', complianceRateStr, Icons.check_circle_outline, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Present Count', '$presentCount', Icons.people_alt_outlined, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Absence Rate', absenceRateStr, Icons.person_off_outlined, const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Session-by-Session Roster Table
          const Text('Session Attendance Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),

          if (_sessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('No sessions scheduled yet. Please schedule a session first to track attendance.'),
            )
          else
            ..._sessions.map((s) {
              final sid = s['id'].toString();
              final title = s['session_title'] ?? 'Session';
              final date = s['session_date'] ?? '';
              final time = '${s['start_time'] ?? ''} - ${s['end_time'] ?? ''}';
              final bool isMarked = s['attendance_marked'] == true;
              final String statusDisplay = s['attendance_display_status'] ?? (isMarked ? 'Marked' : 'Pending');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMarked ? Icons.check_circle_outline : Icons.pending_actions_rounded,
                      color: isMarked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text('Date: $date • Time: $time', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMarked ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Status: $statusDisplay',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isMarked ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => RecordAttendanceDialog(
                            sessionId: sid,
                            sessionTitle: title,
                            sessionDate: date,
                            sessionTime: time,
                            onAttendanceSaved: () {
                              _fetchDetails();
                              widget.onProgramUpdated();
                            },
                          ),
                        );
                      },
                      icon: Icon(isMarked ? Icons.edit : Icons.fact_check_outlined, size: 14),
                      label: Text(isMarked ? 'Edit Attendance' : 'Record Attendance', style: const TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 6: ASSESSMENT
  // =========================================================================
  Widget _buildAssessmentTab(bool isDark) {
    final passingScore = (_programData?['passing_score'] != null)
        ? double.tryParse(_programData!['passing_score'].toString()) ?? 70.0
        : 70.0;
    final assessmentType = _programData?['assessment_type'] ?? 'Quiz';
    final passedCount = _participants.where((p) => p['assessment_status'] == 'PASSED').length;
    final failedCount = _participants.where((p) => p['assessment_status'] == 'FAILED').length;
    final pendingCount = _participants.length - passedCount - failedCount;

    final scoredParticipants = _participants.where((p) => p['assessment_score'] != null).toList();
    final avgScore = scoredParticipants.isNotEmpty
        ? scoredParticipants.fold<double>(0.0, (sum, p) => sum + (double.tryParse(p['assessment_score'].toString()) ?? 0.0)) / scoredParticipants.length
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action & Settings Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assessment & Evaluation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      'Evaluation Mode: $assessmentType • Passing: >= ${passingScore.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openConfigureAssessmentDialog,
                    icon: const Icon(Icons.settings_outlined, size: 15),
                    label: const Text('Configure Criteria', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                      side: const BorderSide(color: Color(0xFF4F46E5)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openBulkEvaluateDialog,
                    icon: const Icon(Icons.fact_check_outlined, size: 15),
                    label: const Text('Bulk Evaluate', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Assessment Header Metric Cards: 2 Rows of 3 for spacious layout
          Row(
            children: [
              _buildOverviewCard('Assessment Type', assessmentType, Icons.assignment_outlined, const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Passing Threshold', '>= ${passingScore.toStringAsFixed(0)}%', Icons.verified_outlined, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Average Score', '${avgScore.toStringAsFixed(1)}%', Icons.speed_rounded, const Color(0xFF6366F1), isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildOverviewCard('Passed Staff', '$passedCount', Icons.task_alt, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Failed Staff', '$failedCount', Icons.cancel_outlined, Colors.red, isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Pending Evaluation', '$pendingCount', Icons.hourglass_top_rounded, const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 24),

          // Participants Evaluation Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Participant Assessment Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${_participants.length} Assigned Staff', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 12),

          if (_participants.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No participants assigned to evaluate.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Assign staff members to this course to record scores.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participants.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _participants[i];
                final name = p['employee_name'] ?? 'Staff Member';
                final code = p['employee_code'] ?? 'Emp--';
                final dept = p['department'] ?? 'Academics';
                final stat = (p['assessment_status'] ?? 'PENDING').toString().toUpperCase();
                final score = p['assessment_score'];

                Color outcomeColor = const Color(0xFF10B981);
                if (stat == 'FAILED') outcomeColor = Colors.red;
                if (stat == 'PENDING') outcomeColor = const Color(0xFFF59E0B);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        child: Text(name.isNotEmpty ? name[0] : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('$code • $dept', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: outcomeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: outcomeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$stat ${score != null ? '($score%)' : ''}',
                          style: TextStyle(color: outcomeColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _openRecordScoreDialog(p),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Record Score', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 7: CERTIFICATES
  // =========================================================================
  Widget _buildCertificatesTab(bool isDark) {
    final validCount = _certificates.where((c) => (c['status'] ?? '').toString().toUpperCase() == 'VALID').length;
    final revokedCount = _certificates.where((c) => ['EXPIRED', 'REVOKED'].contains((c['status'] ?? '').toString().toUpperCase())).length;

    // Eligible participants: completed coursework OR passed assessment, and don't already have a valid certificate
    final eligibleParticipants = _participants.where((p) {
      final stat = (p['status'] ?? '').toString().toUpperCase();
      final aStat = (p['assessment_status'] ?? '').toString().toUpperCase();
      final score = p['assessment_score'];
      final hasCert = _certificates.any((c) =>
          c['employee_id'] == p['employee_id'] && (c['status'] ?? '').toString().toUpperCase() == 'VALID');
      return (stat == 'COMPLETED' || aStat == 'PASSED' || (score != null && (score as num) >= 70)) && !hasCert;
    }).toList();

    final allEligibleIds = eligibleParticipants.map((p) => p['employee_id'].toString()).toSet();
    final bool allSelected = eligibleParticipants.isNotEmpty && _selectedEligibleEmpIds.containsAll(allEligibleIds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Certificate Metric Cards
          Row(
            children: [
              _buildOverviewCard('Total Issued', '${_certificates.length}', Icons.workspace_premium_rounded, const Color(0xFF4F46E5), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Valid Certificates', '$validCount', Icons.verified_rounded, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Eligible to Issue', '${eligibleParticipants.length}', Icons.auto_awesome, const Color(0xFF6366F1), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Revoked / Expired', '$revokedCount', Icons.history_edu_rounded, const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // SECTION 1: ELIGIBLE PARTICIPANTS SELECTION & GENERATION
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 8),
                              Text(
                                'Eligible for Certification (${eligibleParticipants.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select single or multiple eligible staff members to generate official completion certificates.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (eligibleParticipants.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                if (allSelected) {
                                  _selectedEligibleEmpIds.clear();
                                } else {
                                  _selectedEligibleEmpIds.addAll(allEligibleIds);
                                }
                              });
                            },
                            icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded, size: 15),
                            label: Text(allSelected ? 'Deselect All' : 'Select All (${eligibleParticipants.length})', style: const TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFF4F46E5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: (_selectedEligibleEmpIds.isEmpty || _isGeneratingCertificates)
                                ? null
                                : () => _generateCertificatesForSelected(_selectedEligibleEmpIds.toList()),
                            icon: _isGeneratingCertificates
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.workspace_premium_rounded, size: 15),
                            label: Text(
                              _selectedEligibleEmpIds.isEmpty
                                  ? 'Generate Selected (0)'
                                  : 'Generate Selected (${_selectedEligibleEmpIds.length})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (eligibleParticipants.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _participants.isEmpty
                                ? 'No participants assigned to this training program yet.'
                                : 'All completed and passing participants currently have valid certificates issued.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: eligibleParticipants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = eligibleParticipants[i];
                      final empId = p['employee_id'].toString();
                      final name = p['employee_name'] ?? 'Staff Member';
                      final code = p['employee_code'] ?? 'Emp--';
                      final dept = p['department'] ?? 'Academics';
                      final stat = (p['status'] ?? '').toString().toUpperCase();
                      final score = p['assessment_score'];
                      final isSelected = _selectedEligibleEmpIds.contains(empId);

                      String reasonText = stat == 'COMPLETED' ? 'Course Completed' : 'Assessment Passed';
                      if (score != null) reasonText = '$reasonText ($score%)';

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.15 : 0.05)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedEligibleEmpIds.add(empId);
                                  } else {
                                    _selectedEligibleEmpIds.remove(empId);
                                  }
                                });
                              },
                            ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              child: Text(
                                name.isNotEmpty ? name[0] : 'E',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('$code • $dept', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                reasonText,
                                style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isGeneratingCertificates ? null : () => _issueCertificate(empId),
                              icon: const Icon(Icons.workspace_premium_rounded, size: 14),
                              label: const Text('Issue Certificate', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ===================================================================
          // SECTION 2: ISSUED CERTIFICATES LIST
          // ===================================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issued & Verified Certificates (${_certificates.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (eligibleParticipants.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isGeneratingCertificates ? null : _generateAllCertificates,
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  label: Text('Generate All (${eligibleParticipants.length})', style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_certificates.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.workspace_premium_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No certificates issued for this training program yet.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Use the eligible staff list above to generate certificates for individual or multiple staff members.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _certificates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final c = _certificates[i];
                final certNo = c['certificate_number'] ?? 'CERT-TRN-001';
                final empName = c['employee_name'] ?? 'Staff Member';
                final issueDate = c['issue_date'] ?? '';
                final expiryDate = c['expiry_date'] ?? 'Permanent';
                final stat = (c['status'] ?? 'VALID').toString().toUpperCase();
                final isValid = stat == 'VALID';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isValid ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isValid ? Icons.workspace_premium_rounded : Icons.block_outlined,
                          color: isValid ? const Color(0xFF10B981) : Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(certNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4F46E5))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isValid ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    stat,
                                    style: TextStyle(
                                      color: isValid ? const Color(0xFF10B981) : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Issued to: $empName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('Issue Date: $issueDate • Validity: $expiryDate', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility_outlined, size: 14),
                            label: const Text('Preview', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                            onPressed: () => _previewCertificateDialog(c),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: const Text('PDF', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _downloadCertificatePdf(c),
                          ),
                          if (isValid)
                            IconButton(
                              icon: const Icon(Icons.block_outlined, size: 18, color: Colors.red),
                              tooltip: 'Revoke Certificate',
                              onPressed: () => _revokeCertificate(c['id'].toString(), certNo, empName),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 8: FEEDBACK
  // =========================================================================
  Widget _buildFeedbackTab(bool isDark) {
    final avgRating = (_feedbackStats['avg_rating'] != null)
        ? double.tryParse(_feedbackStats['avg_rating'].toString()) ?? 0.0
        : 0.0;
    final avgTrainer = (_feedbackStats['avg_trainer_rating'] != null)
        ? double.tryParse(_feedbackStats['avg_trainer_rating'].toString()) ?? 0.0
        : 0.0;
    final avgContent = (_feedbackStats['avg_content_rating'] != null)
        ? double.tryParse(_feedbackStats['avg_content_rating'].toString()) ?? 0.0
        : 0.0;
    final totalReviews = _feedbackList.length;

    // Star counts distribution
    final starCounts = (_feedbackStats['star_counts'] as Map<String, dynamic>?) ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feedback Top Stats
          Row(
            children: [
              _buildOverviewCard('Average Rating', '${avgRating.toStringAsFixed(1)} ★', Icons.star_rounded, const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Trainer Effectiveness', '${avgTrainer.toStringAsFixed(1)} ★', Icons.person_search_rounded, const Color(0xFF10B981), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Content Quality', '${avgContent.toStringAsFixed(1)} ★', Icons.menu_book_rounded, const Color(0xFF0284C7), isDark),
              const SizedBox(width: 12),
              _buildOverviewCard('Total Reviews', '$totalReviews', Icons.reviews_outlined, const Color(0xFF4F46E5), isDark),
            ],
          ),
          const SizedBox(height: 20),

          // Rating Breakdown Bars
          if (totalReviews > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rating Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  ...[5, 4, 3, 2, 1].map((stars) {
                    final count = int.tryParse(starCounts['$stars']?.toString() ?? '0') ?? 0;
                    final pct = totalReviews > 0 ? count / totalReviews : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text('$stars ★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 30,
                            child: Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Submit Feedback Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Participant Reviews & Testimonials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                onPressed: _openSubmitFeedbackDialog,
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Submit Feedback'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_feedbackList.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No feedback recorded yet.', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Submit reviews to evaluate trainer and course quality.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openSubmitFeedbackDialog,
                    icon: const Icon(Icons.star_outline_rounded, size: 16),
                    label: const Text('Add Participant Review'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                  ),
                ],
              ),
            )
          else
            ..._feedbackList.map((f) {
              final name = f['employee_name'] ?? 'Faculty Member';
              final rating = int.tryParse(f['rating']?.toString() ?? '5') ?? 5;
              final tRating = int.tryParse(f['trainer_rating']?.toString() ?? '5') ?? 5;
              final cRating = int.tryParse(f['content_rating']?.toString() ?? '5') ?? 5;
              final text = f['feedback_text'] ?? 'Insightful and practical session!';
              final date = f['created_at'] ?? 'Recently';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Row(
                          children: List.generate(5, (idx) {
                            return Icon(
                              idx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 16,
                              color: const Color(0xFFF59E0B),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(text, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text('Trainer: $tRating/5 ★', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        Text('Content: $cRating/5 ★', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        Text('$date', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 9: ACTIVITY
  // =========================================================================
  Widget _buildActivityTab(bool isDark) {
    return _activityLogs.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text('No logged activities for this course yet.'),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _activityLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final a = _activityLogs[i];
              final action = (a['action'] ?? 'ACTIVITY').toString().toUpperCase();
              final summary = a['summary'] ?? 'Training operation recorded';
              final performer = a['performer_name'] ?? 'System';
              final time = a['created_at'] ?? 'Recently';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFF4F46E5), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(action.replaceAll('_', ' '), style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                              Text('$time', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(summary, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('By: $performer', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
