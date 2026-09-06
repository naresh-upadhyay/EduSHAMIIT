import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';
import '../../../classes/services/class_api_service.dart';
import '../../../classes/models/class_models.dart';

class DigitalFileDraft {
  final String id;
  late final TextEditingController titleCtrl;
  String fileType; // EBOOK_PDF, EBOOK_EPUB, AUDIO_MP3, VIDEO_MP4, VIDEO_HLS
  String sourceType; // FILE_UPLOAD, DIRECT_LINK, LIVE_STREAM, YOUTUBE_STREAM
  String storageKey;
  String fileName;
  String streamUrl;
  String mimeType;
  int fileSizeBytes;
  int durationSeconds;
  int pageCount;
  bool isPrimary;
  bool isLiveStream;
  int sortOrder;
  bool isUploading;

  DigitalFileDraft({
    String? id,
    String? title,
    this.fileType = 'EBOOK_PDF',
    this.sourceType = 'FILE_UPLOAD',
    this.storageKey = '',
    this.fileName = 'Resource',
    this.streamUrl = '',
    this.mimeType = 'application/pdf',
    this.fileSizeBytes = 0,
    this.durationSeconds = 0,
    this.pageCount = 0,
    this.isPrimary = false,
    this.isLiveStream = false,
    this.sortOrder = 0,
    this.isUploading = false,
  })  : id = (id != null && id.isNotEmpty) ? id : 'draft_${DateTime.now().microsecondsSinceEpoch}_${UniqueKey().toString()}' {
    final t = (title != null && title.trim().isNotEmpty) ? title.trim() : fileName;
    titleCtrl = TextEditingController(text: t);
  }

  String get title => titleCtrl.text.trim();
  set title(String v) => titleCtrl.text = v;

  void dispose() {
    titleCtrl.dispose();
  }

  factory DigitalFileDraft.fromModel(DigitalFileModel m) {
    return DigitalFileDraft(
      id: m.id,
      title: m.title ?? m.fileName,
      fileType: m.fileType,
      sourceType: m.sourceType,
      storageKey: m.storageKey,
      fileName: m.fileName,
      streamUrl: m.streamUrl ?? '',
      mimeType: m.mimeType,
      fileSizeBytes: m.fileSizeBytes,
      durationSeconds: m.durationSeconds,
      pageCount: m.pageCount,
      isPrimary: m.isPrimary,
      isLiveStream: m.isLiveStream,
      sortOrder: m.sortOrder,
    );
  }

  Map<String, dynamic> toPayload(int index) {
    final effectiveTitle = title.isNotEmpty ? title : fileName;
    return {
      'file_type': fileType,
      'source_type': sourceType,
      'title': effectiveTitle,
      'storage_key': storageKey.isNotEmpty ? storageKey : (streamUrl.isNotEmpty ? streamUrl : 'asset_${index}_$fileName'),
      'file_name': fileName.trim().isNotEmpty ? fileName.trim() : 'Digital Resource',
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'duration_seconds': durationSeconds,
      'page_count': pageCount,
      'stream_url': streamUrl.trim(),
      'is_primary': isPrimary,
      'is_live_stream': isLiveStream,
      'sort_order': index,
    };
  }
}

class AddEditBookDialog extends ConsumerStatefulWidget {
  final BookModel? book;
  const AddEditBookDialog({super.key, this.book});

  @override
  ConsumerState<AddEditBookDialog> createState() => _AddEditBookDialogState();
}

class _AddEditBookDialogState extends ConsumerState<AddEditBookDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  bool _isUploadingCover = false;
  bool _isSaving = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _subtitleCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _isbn13Ctrl;
  late TextEditingController _isbn10Ctrl;
  late TextEditingController _publisherCtrl;
  late TextEditingController _pagesCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _rackCtrl;
  late TextEditingController _shelfCtrl;
  late TextEditingController _coverUrlCtrl;
  late TextEditingController _totalCopiesCtrl;
  late TextEditingController _availableCopiesCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _supplierCtrl;

  // Digital Specific Controllers
  late TextEditingController _subjectCtrl;
  late TextEditingController _gradeLevelCtrl;
  late TextEditingController _accessDurationCtrl;

  String _selectedCategory = 'Finance';
  String _selectedLanguage = 'English';
  String _selectedBookType = 'Physical Book';
  String _selectedFinancialYear = '';
  String _selectedStatus = 'ACTIVE';
  String _selectedCondition = 'GOOD';
  String _selectedAcquisitionType = 'PURCHASE';

  // Digital & DRM Options
  bool _isDigital = false;
  String _digitalVisibility = 'PUBLIC';
  String _selectedTargetRole = 'STUDENT';
  String _selectedMinAgeLimit = 'None / All Ages';
  bool _allowNotes = true;
  bool _allowHighlights = true;
  bool _allowBookmarks = true;
  bool _allowCopyText = false;
  bool _allowScreenshots = false;
  String _difficultyLevel = 'Intermediate';

  // Multi-Asset List
  final List<DigitalFileDraft> _digitalFiles = [];
  List<String> _dynamicClasses = [];
  List<String> _dynamicSubjects = [];

  static String _normalizeCondition(String raw) {
    final s = raw.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_').replaceAll('/', '_');
    if (s.contains('NEW') || s.contains('MINT')) return 'NEW';
    if (s.contains('EXCELLENT')) return 'EXCELLENT';
    if (s.contains('GOOD')) return 'GOOD';
    if (s.contains('FAIR')) return 'FAIR';
    if (s.contains('WORN')) return 'WORN';
    if (s.contains('DAMAGED')) return 'DAMAGED';
    if (s.contains('REPAIR')) return 'UNDER_REPAIR';
    if (s.contains('LOST') || s.contains('MISSING')) return 'LOST';
    return s;
  }

  @override
  void initState() {
    super.initState();
    _loadAcademicLookups();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bookProvider.notifier).loadFilterOptions();
      }
    });

    final b = widget.book;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _subtitleCtrl = TextEditingController(text: b?.subtitle ?? '');
    _authorCtrl = TextEditingController(text: b?.author ?? '');
    _isbn13Ctrl = TextEditingController(text: b?.isbn13 ?? '');
    _isbn10Ctrl = TextEditingController(text: b?.isbn10 ?? '');
    _publisherCtrl = TextEditingController(text: b?.publisher ?? '');
    _pagesCtrl = TextEditingController(text: b?.pages != null ? b!.pages.toString() : '');
    _descriptionCtrl = TextEditingController(text: b?.description ?? '');
    _rackCtrl = TextEditingController(text: b?.rackLocation ?? 'Rack A');
    _shelfCtrl = TextEditingController(text: b?.shelfLocation ?? 'Shelf 1');
    _coverUrlCtrl = TextEditingController(text: b?.coverUrl ?? '');
    _totalCopiesCtrl = TextEditingController(text: b != null ? b.totalCopies.toString() : '1');
    _availableCopiesCtrl = TextEditingController(text: b != null ? b.availableCopies.toString() : '1');
    _priceCtrl = TextEditingController(
      text: b?.purchasePrice != null ? b!.purchasePrice!.toStringAsFixed(2) : '299.00',
    );
    _supplierCtrl = TextEditingController(text: b?.supplier ?? 'Sapna Book House');

    _subjectCtrl = TextEditingController(text: b?.subject ?? '');
    _gradeLevelCtrl = TextEditingController(text: b?.gradeLevel ?? '');
    _accessDurationCtrl = TextEditingController(
      text: b?.defaultAccessDurationDays != null ? b!.defaultAccessDurationDays.toString() : '30',
    );
    _tabController = TabController(length: 4, vsync: this);

    if (b != null) {
      _selectedCategory = b.categoryName;
      _selectedLanguage = b.languageName;
      _selectedBookType = b.bookTypeName;
      if (b.financialYear != null && b.financialYear!.isNotEmpty) {
        _selectedFinancialYear = b.financialYear!;
      } else if (b.publicationYear != null) {
        _selectedFinancialYear = '${b.publicationYear}';
      }
      _selectedStatus = b.status.toUpperCase();
      if (b.primaryCondition != null && b.primaryCondition!.isNotEmpty) {
        _selectedCondition = _normalizeCondition(b.primaryCondition!);
      }
      final typeLower = b.bookTypeName.toLowerCase();
      _isDigital = b.isDigital ||
          b.digitalFiles.isNotEmpty ||
          typeLower.contains('ebook') ||
          typeLower.contains('e-book') ||
          typeLower.contains('audio') ||
          typeLower.contains('video') ||
          typeLower.contains('digital');
      if (b.digitalVisibility.isNotEmpty) {
        final dv = b.digitalVisibility.toUpperCase();
        _digitalVisibility = (dv == 'UNLISTED') ? 'INTERNAL' : dv;
      }
      if (b.allowedRoles.isNotEmpty) {
        _selectedTargetRole = b.allowedRoles.first.toUpperCase();
      }
      if (b.ageGroup != null && b.ageGroup!.isNotEmpty) {
        _selectedMinAgeLimit = b.ageGroup!;
      }
      _allowNotes = b.allowNotes;
      _allowHighlights = b.allowHighlights;
      _allowBookmarks = b.allowBookmarks;
      _allowCopyText = b.allowCopyText;
      _allowScreenshots = b.allowScreenshots;
      _difficultyLevel = b.difficultyLevel ?? 'Intermediate';
      if (b.acquisitionType != null && b.acquisitionType!.isNotEmpty) {
        _selectedAcquisitionType = b.acquisitionType!;
      }

      for (var f in b.digitalFiles) {
        _digitalFiles.add(DigitalFileDraft.fromModel(f));
      }
    }

  }

  @override
  void dispose() {
    for (var f in _digitalFiles) {
      f.dispose();
    }
    _tabController.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _authorCtrl.dispose();
    _isbn13Ctrl.dispose();
    _isbn10Ctrl.dispose();
    _publisherCtrl.dispose();
    _pagesCtrl.dispose();
    _descriptionCtrl.dispose();
    _rackCtrl.dispose();
    _shelfCtrl.dispose();
    _coverUrlCtrl.dispose();
    _totalCopiesCtrl.dispose();
    _availableCopiesCtrl.dispose();
    _priceCtrl.dispose();
    _supplierCtrl.dispose();
    _subjectCtrl.dispose();
    _gradeLevelCtrl.dispose();
    _accessDurationCtrl.dispose();
    super.dispose();
  }

  // Cover Photo State
  Uint8List? _localCoverBytes;

  Future<void> _pickAndUploadCover() async {

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() {
        _localCoverBytes = bytes;
        _isUploadingCover = true;
      });

      final api = ref.read(libraryApiServiceProvider);
      final uploadedUrl = await api.uploadCoverImage(bytes, file.name);
      if (mounted) {
        final resolvedUrl = AppConfig.resolveUrl(uploadedUrl);
        setState(() {
          _coverUrlCtrl.text = resolvedUrl;
          _isUploadingCover = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cover image uploaded successfully!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingCover = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload cover image: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  /// Multi-File Picker & Direct Storage Uploader
  Future<void> _pickAndUploadMultipleDigitalFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'mp3', 'wav', 'm4a', 'mp4', 'webm', 'mov'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final api = ref.read(libraryApiServiceProvider);

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final ext = (file.extension ?? 'pdf').toLowerCase();
        String fileType = 'EBOOK_PDF';
        String mimeType = 'application/pdf';

        if (['mp3', 'wav', 'm4a'].contains(ext)) {
          fileType = 'AUDIO_MP3';
          mimeType = 'audio/mpeg';
        } else if (['mp4', 'webm', 'mov'].contains(ext)) {
          fileType = 'VIDEO_MP4';
          mimeType = 'video/mp4';
        } else if (ext == 'epub') {
          fileType = 'EBOOK_EPUB';
          mimeType = 'application/epub+zip';
        }

        final draft = DigitalFileDraft(
          title: file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
          fileName: file.name,
          fileType: fileType,
          sourceType: 'FILE_UPLOAD',
          mimeType: mimeType,
          fileSizeBytes: file.size,
          isPrimary: _digitalFiles.isEmpty,
          isUploading: true,
        );

        setState(() {
          _digitalFiles.add(draft);
          _isDigital = true;
        });

        try {
          final res = await api.uploadDigitalFile(bytes, file.name);
          if (mounted) {
            setState(() {
              draft.streamUrl = res['stream_url']?.toString() ?? res['url']?.toString() ?? '';
              draft.storageKey = res['storage_key']?.toString() ?? draft.streamUrl;
              draft.isUploading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => draft.isUploading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload ${file.name}: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Add Direct Link or Live Stream URL Dialog
  void _showAddLinkOrLiveStreamDialog() {
    final titleCtrl = TextEditingController(text: 'Chapter / Live Lecture');
    final urlCtrl = TextEditingController(text: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');

    String selectedType = 'VIDEO_HLS';
    String sourceType = 'LIVE_STREAM';
    bool isLive = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                Icon(isLive ? Icons.live_tv_rounded : Icons.link_rounded, color: isLive ? Colors.red : const Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Text(isLive ? 'Add Live Stream Link' : 'Add Direct Stream URL', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Asset / Stream Title *', hintText: 'e.g. Weekly Live Problem Solving Stream'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Resource Type'),
                    items: const [
                      DropdownMenuItem(value: 'VIDEO_HLS', child: Text('Live Stream / HLS (.m3u8)')),
                      DropdownMenuItem(value: 'VIDEO_MP4', child: Text('Video Lecture Stream (MP4 / WebM)')),
                      DropdownMenuItem(value: 'AUDIO_MP3', child: Text('Audio Stream URL (MP3 / Podcast)')),
                      DropdownMenuItem(value: 'EBOOK_PDF', child: Text('Direct PDF Document Link')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() {
                          selectedType = v;
                          isLive = (v == 'VIDEO_HLS');
                          sourceType = isLive ? 'LIVE_STREAM' : 'DIRECT_LINK';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Stream URL / Link *',
                      hintText: isLive ? 'https://.../stream.m3u8 or YouTube / Vimeo Live' : 'https://.../audio_or_doc.mp3',
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Mark as Active Live Stream Broadcast', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Displays a pulsing live indicator in reader/player', style: TextStyle(fontSize: 11)),
                    value: isLive,
                    activeColor: Colors.red,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => isLive = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  final url = urlCtrl.text.trim();
                  if (url.isEmpty) return;

                  final ext = url.split('?').first.split('.').last.toLowerCase();
                  String mime = 'video/mp4';
                  if (isLive || ext == 'm3u8') {
                    mime = 'application/x-mpegURL';
                  } else if (['mp3', 'wav', 'm4a'].contains(ext) || selectedType == 'AUDIO_MP3') {
                    mime = 'audio/mpeg';
                  } else if (ext == 'pdf' || selectedType == 'EBOOK_PDF') {
                    mime = 'application/pdf';
                  }

                  final draft = DigitalFileDraft(
                    title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Live Stream Resource',
                    fileName: url.split('/').last.split('?').first,
                    fileType: selectedType,
                    sourceType: isLive ? 'LIVE_STREAM' : 'DIRECT_LINK',
                    mimeType: mime,
                    streamUrl: url,
                    storageKey: url,
                    isLiveStream: isLive,
                    isPrimary: _digitalFiles.isEmpty,
                  );

                  setState(() {
                    _digitalFiles.add(draft);
                    _isDigital = true;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Add Stream Asset'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadAcademicLookups() async {
    try {
      final classApi = ClassApiService();
      final results = await Future.wait([
        classApi.getClasses(pageSize: 100),
        classApi.getSubjects(pageSize: 100),
      ]);

      final classesData = results[0];
      final subjectsData = results[1];

      final classNames = (classesData['classes'] as List<AcademicClassModel>? ?? [])
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      classNames.sort();

      final subjectNames = (subjectsData['subjects'] as List<AcademicSubjectModel>? ?? [])
          .map((s) => s.name.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      subjectNames.sort();

      if (mounted) {
        setState(() {
          _dynamicClasses = classNames;
          _dynamicSubjects = subjectNames;
        });
        debugPrint('[AddEditBookDialog] Loaded ${_dynamicClasses.length} classes and ${_dynamicSubjects.length} subjects');
      }
    } catch (e) {
      debugPrint('[AddEditBookDialog] Error loading academic lookups: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.book != null;
    final state = ref.watch(bookProvider);

    final categories = state.filterOptions.categories;
    final yearOptions = state.filterOptions.years;
    final languages = state.filterOptions.languages;
    final bookTypes = state.filterOptions.bookTypes;
    const defaultConditions = [
      'NEW',
      'EXCELLENT',
      'GOOD',
      'FAIR',
      'WORN',
      'DAMAGED',
      'UNDER_REPAIR',
      'LOST'
    ];
    final conditionOptions = <String>[];
    for (final c in state.filterOptions.conditions) {
      final code = _normalizeCondition(c);
      if (!conditionOptions.contains(code)) conditionOptions.add(code);
    }
    if (conditionOptions.isEmpty) {
      for (final c in defaultConditions) {
        if (!conditionOptions.contains(c)) conditionOptions.add(c);
      }
    }

    _selectedCondition = _normalizeCondition(_selectedCondition);
    if (!conditionOptions.contains(_selectedCondition) && conditionOptions.isNotEmpty) {
      _selectedCondition = conditionOptions.first;
    }

    final subjectsList = <String>['General / All Subjects'];
    for (final s in _dynamicSubjects) {
      if (!subjectsList.contains(s)) subjectsList.add(s);
    }
    for (final s in state.filterOptions.subjects) {
      if (!subjectsList.contains(s)) subjectsList.add(s);
    }
    if (_subjectCtrl.text.trim().isNotEmpty && !subjectsList.contains(_subjectCtrl.text.trim())) {
      subjectsList.add(_subjectCtrl.text.trim());
    }

    final classesList = <String>['All Classes / Grades'];
    for (final c in _dynamicClasses) {
      if (!classesList.contains(c)) classesList.add(c);
    }
    for (final c in state.filterOptions.classes) {
      if (!classesList.contains(c)) classesList.add(c);
    }
    if (_gradeLevelCtrl.text.trim().isNotEmpty && !classesList.contains(_gradeLevelCtrl.text.trim())) {
      classesList.add(_gradeLevelCtrl.text.trim());
    }

    if (!categories.contains(_selectedCategory) && categories.isNotEmpty) _selectedCategory = categories.first;
    if (!yearOptions.contains(_selectedFinancialYear) && yearOptions.isNotEmpty) {
      _selectedFinancialYear = yearOptions.firstWhere(
        (fy) => fy.startsWith(_selectedFinancialYear),
        orElse: () => yearOptions.first,
      );
    }
    if (!languages.contains(_selectedLanguage) && languages.isNotEmpty) _selectedLanguage = languages.first;
    if (!bookTypes.contains(_selectedBookType) && bookTypes.isNotEmpty) _selectedBookType = bookTypes.first;
    if (!conditionOptions.contains(_selectedCondition) && conditionOptions.isNotEmpty) _selectedCondition = conditionOptions.first;

    final availableRoles = state.filterOptions.roles;
    final List<String> roleCodeOptions = [];
    final Map<String, String> roleDisplayMap = {};

    if (availableRoles.isNotEmpty) {
      for (final r in availableRoles) {
        final code = r.code.toUpperCase();
        if (!roleCodeOptions.contains(code)) {
          roleCodeOptions.add(code);
          roleDisplayMap[code] = r.displayName;
        }
      }
    } else {
      const defaultRoles = [
        'STUDENT',
        'TEACHER',
        'CLASS_TEACHER',
        'SUBJECT_TEACHER',
        'ACADEMIC_ADMIN',
        'INSTITUTION_ADMIN',
        'LIBRARIAN',
        'STUDENT_PARENT'
      ];
      for (final r in defaultRoles) {
        roleCodeOptions.add(r);
        roleDisplayMap[r] = _formatOptionLabel(r);
      }
    }

    if (!roleCodeOptions.contains(_selectedTargetRole) && roleCodeOptions.isNotEmpty) {
      _selectedTargetRole = roleCodeOptions.first;
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 890),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note_rounded : Icons.auto_stories_rounded,
                    color: const Color(0xFF6366F1),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Publication / Title' : 'Add New Library Publication',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Multi-Asset Digital Publishing, Live Streaming & DRM Access Control',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: [
                  const Tab(icon: Icon(Icons.menu_book, size: 16), text: '1. Basic Info'),
                  const Tab(icon: Icon(Icons.category, size: 16), text: '2. Classification'),
                  const Tab(icon: Icon(Icons.inventory_2, size: 16), text: '3. Physical Stock'),
                  Tab(
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    text: _digitalFiles.isNotEmpty ? '4. Digital & DRM (${_digitalFiles.length})' : '4. Digital & DRM',
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Basic Info
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(label: 'Book Title *', controller: _titleCtrl, isDark: isDark, isRequired: true),
                          const SizedBox(height: 14),
                          _buildTextField(label: 'Subtitle', controller: _subtitleCtrl, isDark: isDark),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'Author *', controller: _authorCtrl, isDark: isDark, isRequired: true)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildTextField(label: 'Publisher', controller: _publisherCtrl, isDark: isDark)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'ISBN-13', controller: _isbn13Ctrl, isDark: isDark)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildTextField(label: 'ISBN-10', controller: _isbn10Ctrl, isDark: isDark)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'Pages', controller: _pagesCtrl, isDark: isDark, isNumber: true)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Publication / Financial Year',
                                  value: _selectedFinancialYear,
                                  items: yearOptions,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedFinancialYear = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(label: 'Description / Abstract', controller: _descriptionCtrl, isDark: isDark, maxLines: 3),
                        ],
                      ),
                    ),

                    // Tab 2: Classification
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Category (Lookup) *',
                                  value: _selectedCategory,
                                  items: categories,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedCategory = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Language (Lookup) *',
                                  value: _selectedLanguage,
                                  items: languages,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedLanguage = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Book Type (Lookup) *',
                                  value: _selectedBookType,
                                  items: bookTypes,
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        _selectedBookType = v;
                                        final lower = v.toLowerCase();
                                        if (lower.contains('ebook') || lower.contains('e-book') || lower.contains('audio') || lower.contains('video') || lower.contains('digital')) {
                                          _isDigital = true;
                                        }
                                      });
                                    }
                                  },
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Difficulty Level',
                                  value: _difficultyLevel,
                                  items: const ['Beginner', 'Intermediate', 'Advanced', 'Expert'],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _difficultyLevel = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Academic Subject (Class Management)',
                                  value: _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : (subjectsList.isNotEmpty ? subjectsList.first : ''),
                                  items: subjectsList,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _subjectCtrl.text = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Grade / Target Class (Class Management)',
                                  value: _gradeLevelCtrl.text.trim().isNotEmpty ? _gradeLevelCtrl.text.trim() : (classesList.isNotEmpty ? classesList.first : ''),
                                  items: classesList,
                                  onChanged: (v) {
                                    if (v != null) setState(() => _gradeLevelCtrl.text = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCoverPhotoSection(isDark),
                        ],
                      ),
                    ),

                    // Tab 3: Physical Stock
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'Rack Location', controller: _rackCtrl, isDark: isDark)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildTextField(label: 'Shelf Location', controller: _shelfCtrl, isDark: isDark)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'Initial Copies Count', controller: _totalCopiesCtrl, isDark: isDark, isNumber: true)),
                              const SizedBox(width: 14),
                              Expanded(child: _buildTextField(label: 'Purchase Price (₹)', controller: _priceCtrl, isDark: isDark, isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildTextField(label: 'Supplier / Vendor', controller: _supplierCtrl, isDark: isDark)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildDropdownField(
                                  label: 'Initial Condition',
                                  value: _selectedCondition,
                                  items: conditionOptions,
                                  labelBuilder: (code) {
                                    const map = {
                                      'NEW': 'New / Mint',
                                      'EXCELLENT': 'Excellent Condition',
                                      'GOOD': 'Good Condition',
                                      'FAIR': 'Fair Condition',
                                      'WORN': 'Worn Condition',
                                      'DAMAGED': 'Damaged Condition',
                                      'UNDER_REPAIR': 'Under Repair',
                                      'LOST': 'Lost / Missing',
                                    };
                                    return map[code] ?? _formatOptionLabel(code);
                                  },
                                  onChanged: (v) {
                                    if (v != null) setState(() => _selectedCondition = v);
                                  },
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tab 4: Multi-Asset Digital Assets & Live Streams & DRM
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('Digital Edition Available', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text('Enable multi-asset reading, audio listening, video lectures, and live streaming.'),
                            value: _isDigital,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (v) => setState(() => _isDigital = v),
                          ),
                          const Divider(),
                          if (_isDigital) ...[
                            const SizedBox(height: 14),
                            // Row: Digital Visibility / Display Mode & Role Access
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildDropdownField(
                                    label: 'Display Mode / Digital Visibility *',
                                    value: _digitalVisibility,
                                    items: const ['PUBLIC', 'INTERNAL', 'RESTRICTED'],
                                    labelBuilder: (v) {
                                      switch (v) {
                                        case 'PUBLIC':
                                          return 'Public (Open Access)';
                                        case 'INTERNAL':
                                          return 'Internal (Role-Based Access)';
                                        case 'RESTRICTED':
                                          return 'Restricted (Approval Required)';
                                        default:
                                          return _formatOptionLabel(v);
                                      }
                                    },
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() {
                                          _digitalVisibility = v;
                                        });
                                      }
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                                if (_digitalVisibility != 'PUBLIC') ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdownField(
                                      label: 'Allowed Role (from App Roles) *',
                                      value: _selectedTargetRole,
                                      items: roleCodeOptions,
                                      labelBuilder: (code) => roleDisplayMap[code] ?? _formatOptionLabel(code),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedTargetRole = v);
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                                if (_digitalVisibility != 'PUBLIC' &&
                                    (_selectedTargetRole.toUpperCase() == 'STUDENT' ||
                                        _selectedTargetRole.toUpperCase() == 'STUDENTS')) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: _buildDropdownField(
                                      label: 'Minimum Student Age Limit',
                                      value: _selectedMinAgeLimit,
                                      items: const [
                                        'None / All Ages',
                                        '6+ Years',
                                        '8+ Years',
                                        '10+ Years',
                                        '12+ Years',
                                        '14+ Years',
                                        '16+ Years',
                                        '18+ Years',
                                      ],
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedMinAgeLimit = v);
                                      },
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                                if (_digitalVisibility == 'RESTRICTED') ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTextField(
                                      label: 'Access Duration (Days) *',
                                      controller: _accessDurationCtrl,
                                      isDark: isDark,
                                      isNumber: true,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Dynamic Informative Access Mode Cards
                            if (_digitalVisibility == 'PUBLIC')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.public, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Public Open Access',
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF10B981)),
                                          ),
                                          Text(
                                            'All registered school members can read, listen, and access this publication immediately with zero approval or permission requests required.',
                                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_digitalVisibility == 'INTERNAL')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified_user_outlined, color: Color(0xFF6366F1), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Internal Role Access (${roleDisplayMap[_selectedTargetRole] ?? _selectedTargetRole})',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF6366F1)),
                                          ),
                                          Text(
                                            'Members matching the selected role can read immediately inside the school. No request or approval workflow required.',
                                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_digitalVisibility == 'RESTRICTED')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Restricted Access with Librarian Approval (${roleDisplayMap[_selectedTargetRole] ?? _selectedTargetRole})',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFFF59E0B)),
                                          ),
                                          Text(
                                            'Users must raise a digital access request. Content is unlocked only after a librarian approves the request for ${_accessDurationCtrl.text.trim().isEmpty ? '30' : _accessDurationCtrl.text.trim()} days.',
                                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Multi-Asset Header & Action Buttons
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('Digital Assets & Live Streams', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${_digitalFiles.length} attached',
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Upload multiple PDFs/ePubs, audio chapters, video recordings, or live stream links.',
                                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: _pickAndUploadMultipleDigitalFiles,
                                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                                        label: const Text('Upload Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF6366F1),
                                          side: const BorderSide(color: Color(0xFF6366F1)),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: _showAddLinkOrLiveStreamDialog,
                                        icon: const Icon(Icons.live_tv_rounded, size: 16),
                                        label: const Text('Add Stream / Live Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Multi-Asset Cards List
                            if (_digitalFiles.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), style: BorderStyle.solid),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    const SizedBox(height: 6),
                                    Text('No digital assets attached yet', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                                    const SizedBox(height: 4),
                                    const Text('Click "Upload Files" or "Add Stream / Live Link" to attach multi-format media.', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _digitalFiles.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final file = _digitalFiles[idx];
                                  return _buildDigitalAssetCard(file, idx, isDark);
                                },
                              ),

                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Icon(Icons.shield_outlined, size: 17, color: Color(0xFF6366F1)),
                                const SizedBox(width: 6),
                                const Text('DRM Security & Interaction Rules', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDrmRuleTile(
                                        title: 'Allow In-App Notes',
                                        subtitle: 'Enable note-taking tool in reader',
                                        icon: Icons.note_alt_outlined,
                                        color: const Color(0xFF6366F1),
                                        value: _allowNotes,
                                        onChanged: (v) => setState(() => _allowNotes = v),
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDrmRuleTile(
                                        title: 'Allow Highlights',
                                        subtitle: 'Enable text color highlighting',
                                        icon: Icons.highlight_alt_rounded,
                                        color: const Color(0xFFF59E0B),
                                        value: _allowHighlights,
                                        onChanged: (v) => setState(() => _allowHighlights = v),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDrmRuleTile(
                                        title: 'Allow Bookmarks',
                                        subtitle: 'Save reading progress & markers',
                                        icon: Icons.bookmark_added_outlined,
                                        color: const Color(0xFF10B981),
                                        value: _allowBookmarks,
                                        onChanged: (v) => setState(() => _allowBookmarks = v),
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDrmRuleTile(
                                        title: 'Allow Copy Text',
                                        subtitle: 'Allow clipboard text copying',
                                        icon: Icons.copy_rounded,
                                        color: const Color(0xFF8B5CF6),
                                        value: _allowCopyText,
                                        onChanged: (v) => setState(() => _allowCopyText = v),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildDrmRuleTile(
                                  title: 'Allow Screenshots & Screen Capture',
                                  subtitle: 'Permit device screen recording and screenshots on web & mobile readers',
                                  icon: Icons.screenshot_monitor_rounded,
                                  color: const Color(0xFF06B6D4),
                                  value: _allowScreenshots,
                                  onChanged: (v) => setState(() => _allowScreenshots = v),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _submitForm,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(isEdit ? 'Save Changes' : 'Publish Publication', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalAssetCard(DigitalFileDraft file, int index, bool isDark) {
    IconData icon = Icons.picture_as_pdf;
    Color color = const Color(0xFF10B981);
    String typeLabel = 'PDF eBook';

    if (file.isLiveStream || file.fileType == 'VIDEO_HLS') {
      icon = Icons.live_tv_rounded;
      color = Colors.red;
      typeLabel = '🔴 LIVE STREAM';
    } else if (file.fileType.startsWith('AUDIO')) {
      icon = Icons.headphones;
      color = Colors.purple;
      typeLabel = 'Audiobook';
    } else if (file.fileType.startsWith('VIDEO')) {
      icon = Icons.play_circle_filled;
      color = Colors.orange[800]!;
      typeLabel = 'Video Lecture';
    } else if (file.fileType == 'EBOOK_EPUB') {
      icon = Icons.menu_book;
      color = Colors.teal;
      typeLabel = 'ePub Book';
    }

    return Container(
      key: ValueKey('asset_card_${file.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: file.isPrimary ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: file.isPrimary ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('title_input_${file.id}'),
                        controller: file.titleCtrl,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Enter title / chapter name',
                        ),
                      ),
                    ),
                    if (file.isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(typeLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.streamUrl.isNotEmpty ? file.streamUrl : file.fileName,
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (file.isUploading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            onSelected: (val) {
              if (val == 'set_primary') {
                setState(() {
                  for (var f in _digitalFiles) {
                    f.isPrimary = false;
                  }
                  file.isPrimary = true;
                });
              } else if (val == 'delete') {
                setState(() {
                  _digitalFiles.remove(file);
                  file.dispose();
                  if (file.isPrimary && _digitalFiles.isNotEmpty) {
                    _digitalFiles.first.isPrimary = true;
                  }
                });
              }
            },
            itemBuilder: (ctx) => [
              if (!file.isPrimary) const PopupMenuItem(value: 'set_primary', child: Text('Set as Default Asset')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Asset', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrmRuleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? color.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? color.withValues(alpha: isDark ? 0.6 : 0.4)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: value
                    ? color.withValues(alpha: 0.2)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              activeColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    bool isRequired = false,
    bool isNumber = false,
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          validator: (v) {
            if (isRequired && (v == null || v.trim().isEmpty)) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  static String _formatOptionLabel(String key) {
    const map = {
      'NEW': 'New',
      'EXCELLENT': 'Excellent',
      'GOOD': 'Good',
      'FAIR': 'Fair',
      'DAMAGED': 'Damaged',
      'LOST': 'Lost',
      'UNDER_REPAIR': 'Under Repair',
      'WORN': 'Worn',
      'PUBLIC': 'Public (Open Access)',
      'RESTRICTED': 'Restricted (Permission Required)',
      'UNLISTED': 'Unlisted (Direct Link)',
      'ALL': 'All Members',
      'STUDENT_ONLY': 'Students Only',
      'TEACHER_ONLY': 'Teachers Only',
      'CUSTOM': 'Custom Roles',
      'PURCHASE': 'Purchase',
      'DONATION': 'Donation',
      'GRANT': 'Grant',
      'INTER_LIBRARY_LOAN': 'Inter-Library Loan',
      'ACTIVE': 'Active',
      'ARCHIVED': 'Archived',
      'INACTIVE': 'Inactive',
      'FILE_UPLOAD': 'File Upload',
      'DIRECT_LINK': 'Direct Link',
      'LIVE_STREAM': 'Live Stream',
      'YOUTUBE_STREAM': 'YouTube Stream',
      'EBOOK_PDF': 'eBook (PDF)',
      'EBOOK_EPUB': 'eBook (EPub)',
      'EBOOK_HTML': 'eBook (HTML)',
      'AUDIO_MP3': 'Audiobook (MP3)',
      'VIDEO_MP4': 'Video Lecture (MP4)',
      'VIDEO_HLS': 'Live Stream / HLS (.m3u8)',
    };
    if (map.containsKey(key)) return map[key]!;
    if (key == key.toUpperCase() && key != key.toLowerCase()) {
      return key
          .split('_')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .join(' ');
    }
    return key;
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    String Function(String)? labelBuilder,
  }) {
    final effectiveItems = <String>[];
    for (final it in items) {
      if (!effectiveItems.contains(it)) effectiveItems.add(it);
    }
    if (value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    }
    final validValue = effectiveItems.contains(value)
        ? value
        : (effectiveItems.isNotEmpty ? effectiveItems.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: validValue,
              isExpanded: true,
              hint: Text(
                'Select ${label.split('(').first.trim()}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              selectedItemBuilder: (context) {
                return effectiveItems.map((item) {
                  final displayText = labelBuilder != null ? labelBuilder(item) : _formatOptionLabel(item);
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(displayText, maxLines: 1, overflow: TextOverflow.ellipsis),
                  );
                }).toList();
              },
              items: effectiveItems.map((item) {
                final displayText = labelBuilder != null ? labelBuilder(item) : _formatOptionLabel(item);
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(displayText, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPhotoSection(bool isDark) {

    final hasCover = _localCoverBytes != null || _coverUrlCtrl.text.trim().isNotEmpty;
    final rawUrl = _coverUrlCtrl.text.trim();
    final resolvedUrl = rawUrl.isNotEmpty ? AppConfig.resolveUrl(rawUrl) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Cover Photo Preview Box (80 x 110 px)
              Container(
                width: 80,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isUploadingCover
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6366F1)),
                        ),
                      )
                    : _localCoverBytes != null
                        ? Image.memory(
                            _localCoverBytes!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 110,
                          )
                        : resolvedUrl.isNotEmpty
                            ? Image.network(
                                resolvedUrl,
                                fit: BoxFit.cover,
                                width: 80,
                                height: 110,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    size: 32,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.auto_stories_rounded,
                                  size: 36,
                                  color: const Color(0xFF6366F1).withOpacity(0.5),
                                ),
                              ),
              ),
              const SizedBox(width: 16),

              // 2. Info and Action buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publication Cover Photo',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upload a high-resolution picture (JPG, PNG, WebP up to 5MB). The cover will be visible across search, smart cards, and readers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isUploadingCover ? null : _pickAndUploadCover,
                          icon: _isUploadingCover
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.photo_library_rounded, size: 16),
                          label: Text(
                            _isUploadingCover ? 'Uploading...' : (hasCover ? 'Change Picture' : 'Upload from Local Device'),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (hasCover)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              setState(() {
                                _localCoverBytes = null;
                                _coverUrlCtrl.clear();
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Remove', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (resolvedUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resolvedUrl,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _submitForm() async {

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final notifier = ref.read(bookProvider.notifier);
    final isEdit = widget.book != null;

    int? pubYear;
    if (_selectedFinancialYear.contains('-')) {
      final startYear = _selectedFinancialYear.split('-').first;
      pubYear = int.tryParse(startYear);
    } else {
      pubYear = int.tryParse(_selectedFinancialYear);
    }

    final totalCopies = int.tryParse(_totalCopiesCtrl.text) ?? 1;
    final availableCopies = int.tryParse(_availableCopiesCtrl.text) ?? totalCopies;

    final typeLower = _selectedBookType.toLowerCase();
    final isDigitalEffective = _isDigital ||
        _digitalFiles.isNotEmpty ||
        typeLower.contains('ebook') ||
        typeLower.contains('e-book') ||
        typeLower.contains('audio') ||
        typeLower.contains('video') ||
        typeLower.contains('digital');


    final isPublic = _digitalVisibility == 'PUBLIC';
    final isRestricted = _digitalVisibility == 'RESTRICTED';

    final effectiveAccessMode = isPublic
        ? 'ALL'
        : (isRestricted ? 'RESTRICTED_ROLES' : 'INTERNAL_ROLES');

    final effectiveRequiresPermission = isRestricted;

    final effectiveRoles = isPublic ? <String>[] : <String>[_selectedTargetRole];

    final effectiveAgeGroup = (!isPublic &&
            (_selectedTargetRole.toUpperCase() == 'STUDENT' ||
                _selectedTargetRole.toUpperCase() == 'STUDENTS'))
        ? (_selectedMinAgeLimit == 'None / All Ages' ? null : _selectedMinAgeLimit)
        : null;

    final effectiveDuration = isRestricted
        ? (int.tryParse(_accessDurationCtrl.text.trim()) ?? 30)
        : null;

    final payload = {
      'title': _titleCtrl.text.trim(),
      'subtitle': _subtitleCtrl.text.trim().isEmpty ? null : _subtitleCtrl.text.trim(),
      'author': _authorCtrl.text.trim(),
      'isbn13': _isbn13Ctrl.text.trim().isEmpty ? null : _isbn13Ctrl.text.trim(),
      'isbn10': _isbn10Ctrl.text.trim().isEmpty ? null : _isbn10Ctrl.text.trim(),
      'publisher': _publisherCtrl.text.trim().isEmpty ? null : _publisherCtrl.text.trim(),
      'pages': int.tryParse(_pagesCtrl.text.trim()),
      'category_name': _selectedCategory,
      'language_name': _selectedLanguage,
      'book_type_name': _selectedBookType,
      'publication_year': pubYear ?? 2026,
      'financial_year': _selectedFinancialYear,
      'status': _selectedStatus,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'description': _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
      'rack_location': _rackCtrl.text.trim().isEmpty ? 'Rack A' : _rackCtrl.text.trim(),
      'shelf_location': _shelfCtrl.text.trim().isEmpty ? 'Shelf 1' : _shelfCtrl.text.trim(),
      'cover_url': _coverUrlCtrl.text.trim().isEmpty ? null : _coverUrlCtrl.text.trim(),
      'purchase_price': double.tryParse(_priceCtrl.text) ?? 299.0,
      'supplier': _supplierCtrl.text.trim().isEmpty ? 'Sapna Book House' : _supplierCtrl.text.trim(),
      'condition': _normalizeCondition(_selectedCondition),
      'initial_condition': _normalizeCondition(_selectedCondition),
      'acquisition_type': _selectedAcquisitionType,
      // Digital, Access Control & DRM fields
      'is_digital': isDigitalEffective,
      'digital_visibility': _digitalVisibility,
      'access_mode': effectiveAccessMode,
      'requires_permission': effectiveRequiresPermission,
      'allowed_roles': effectiveRoles,
      'age_group': effectiveAgeGroup,
      'default_access_duration_days': effectiveDuration,
      'subject': _subjectCtrl.text.trim().isEmpty ? null : _subjectCtrl.text.trim(),
      'grade_level': _gradeLevelCtrl.text.trim().isEmpty ? null : _gradeLevelCtrl.text.trim(),
      'difficulty_level': _difficultyLevel,
      'allow_notes': _allowNotes,
      'allow_highlights': _allowHighlights,
      'allow_bookmarks': _allowBookmarks,
      'allow_copy_text': _allowCopyText,
      'allow_screenshots': _allowScreenshots,
      'digital_files': _digitalFiles.map((f) => f.toPayload(_digitalFiles.indexOf(f) + 1)).toList(),
    };

    if (!isEdit) {
      payload['initial_copies_count'] = isDigitalEffective ? 0 : totalCopies;
    }

    try {
      bool success = false;
      if (isEdit) {
        success = await notifier.updateBook(widget.book!.id, payload);
      } else {
        success = await notifier.createBook(payload);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save book: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
