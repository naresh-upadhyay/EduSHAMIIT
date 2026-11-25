import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class RecordingShareDialog extends ConsumerStatefulWidget {
  final RecordingItem recording;

  const RecordingShareDialog({super.key, required this.recording});

  static Future<bool?> show(BuildContext context, RecordingItem recording) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordingShareDialog(recording: recording),
    );
  }

  @override
  ConsumerState<RecordingShareDialog> createState() => _RecordingShareDialogState();
}

class _RecordingShareDialogState extends ConsumerState<RecordingShareDialog> {
  String _mode = 'class_sections'; // 'class_sections' | 'individual'
  String _accessLevel = 'VIEW'; // 'VIEW' | 'DOWNLOAD' | 'MANAGE'
  bool _isLoadingDir = true;
  bool _isLoadingMembers = false;
  bool _isSubmitting = false;

  // Class & multi-section directory state
  List<Map<String, dynamic>> _classes = [];
  String? _selectedClassId;
  final Set<String> _selectedSectionIds = {};
  bool _includeStudents = true;
  bool _includeTeachers = true;
  List<Map<String, dynamic>> _classStudents = [];
  List<Map<String, dynamic>> _classTeachers = [];
  final Map<String, Map<String, dynamic>> _selectedMembersMap = {};

  // Individual search state
  final TextEditingController _searchCtrl = TextEditingController();
  String _roleFilter = '';
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingUsers = false;

  // Existing shares
  List<Map<String, dynamic>> _activeShares = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final api = ref.read(liveClassApiServiceProvider);
    final results = await Future.wait([
      api.fetchShareDirectoryClasses(),
      api.fetchRecordingShares(widget.recording.id),
      api.searchShareUsers(query: ''),
    ]);
    if (!mounted) return;
    final classes = results[0];
    final shares = results[1];
    final initialUsers = results[2];

    String? initClassId = widget.recording.classId;
    if (initClassId == null || !classes.any((c) => c['id']?.toString() == initClassId)) {
      initClassId = classes.isNotEmpty ? classes.first['id']?.toString() : null;
    }

    setState(() {
      _classes = classes;
      _activeShares = shares;
      _searchResults = initialUsers;
      _selectedClassId = initClassId;
      _isLoadingDir = false;
    });

    if (initClassId != null && initClassId.isNotEmpty) {
      await _loadClassMembers();
    }
  }

  Future<void> _loadClassMembers() async {
    if (_selectedClassId == null || _selectedClassId!.isEmpty) return;
    setState(() => _isLoadingMembers = true);
    final api = ref.read(liveClassApiServiceProvider);
    final res = await api.fetchShareClassMembers(
      classId: _selectedClassId!,
      sectionIds: _selectedSectionIds.toList(),
    );
    if (!mounted) return;
    setState(() {
      _classStudents = res['students'] ?? [];
      _classTeachers = res['teachers'] ?? [];
      _isLoadingMembers = false;
    });
  }

  Future<void> _searchUsers([String? query]) async {
    setState(() => _isSearchingUsers = true);
    final api = ref.read(liveClassApiServiceProvider);
    final list = await api.searchShareUsers(
      query: query ?? _searchCtrl.text.trim(),
      role: _roleFilter.isEmpty ? null : _roleFilter,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = list;
      _isSearchingUsers = false;
    });
  }

  Future<void> _revokeShare(String shareId) async {
    final api = ref.read(liveClassApiServiceProvider);
    final ok = await api.revokeRecordingShare(widget.recording.id, shareId);
    if (!mounted) return;
    if (ok) {
      setState(() => _activeShares.removeWhere((s) => s['id']?.toString() == shareId));
      await ref.read(liveClassManagementProvider.notifier).refreshRecordings(selectRecordingId: widget.recording.id);
    }
  }

  Future<void> _submitShare() async {
    setState(() => _isSubmitting = true);
    final api = ref.read(liveClassApiServiceProvider);
    try {
      Map<String, dynamic> payload;
      if (_mode == 'class_sections') {
        final cls = _classes.where((c) => c['id']?.toString() == _selectedClassId).firstOrNull;
        final allSections = (cls?['sections'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        final chosenSections = allSections
            .where((s) => _selectedSectionIds.contains(s['id']?.toString()))
            .map((s) => {'id': s['id'], 'name': s['name']})
            .toList();

        payload = {
          'mode': 'class_sections',
          'class_id': _selectedClassId,
          'class_name': cls?['name'] ?? 'Class',
          'sections': chosenSections,
          'include_students': _includeStudents,
          'include_teachers': _includeTeachers,
          'access_level': _accessLevel,
          if (_selectedMembersMap.isNotEmpty) 'users': _selectedMembersMap.values.toList(),
        };
      } else {
        payload = {
          'mode': 'individual',
          'access_level': _accessLevel,
          'users': _selectedMembersMap.values.toList(),
        };
      }

      final res = await api.shareRecordingBatch(widget.recording.id, payload);
      await ref.read(liveClassManagementProvider.notifier).refreshRecordings(selectRecordingId: widget.recording.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Recording shared successfully.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final card = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final currentCls = _classes.where((c) => c['id']?.toString() == _selectedClassId).firstOrNull;
    final sections = (currentCls?['sections'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    final combinedClassUsers = [
      if (_includeTeachers) ..._classTeachers,
      if (_includeStudents) ..._classStudents,
    ];

    final canSubmit = _mode == 'class_sections'
        ? (_selectedClassId != null && _selectedClassId!.isNotEmpty)
        : _selectedMembersMap.isNotEmpty;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Share Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text(widget.recording.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Mode Selector Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    _modeBtn('class_sections', 'Class & Sections', Icons.account_tree_outlined, textSecondary),
                    _modeBtn('individual', 'Search Individuals', Icons.person_search_rounded, textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Body
              Expanded(
                child: _isLoadingDir
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_mode == 'class_sections') ...[
                              Text('Select Class', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 6),
                              if (_classes.isNotEmpty)
                                AppSearchableDropdown<String>.fromMenuItems(
                                  value: _selectedClassId,
                                  isDense: true,
                                  dropdownColor: bg,
                                  style: TextStyle(fontSize: 12.5, color: textPrimary),
                                  items: _classes.map((c) => DropdownMenuItem<String>(value: c['id']?.toString(), child: Text((c['name'] ?? 'Class').toString()))).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedClassId = v;
                                      _selectedSectionIds.clear();
                                    });
                                    _loadClassMembers();
                                  },
                                ),
                              if (sections.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Select Sections (leave empty for all sections)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: sections.map((sec) {
                                    final sid = sec['id']?.toString() ?? '';
                                    final sname = sec['name']?.toString() ?? '';
                                    final active = _selectedSectionIds.contains(sid);
                                    return FilterChip(
                                      selected: active,
                                      label: Text(sname, style: TextStyle(fontSize: 11, color: active ? Colors.white : textPrimary)),
                                      selectedColor: const Color(0xFF2563EB),
                                      checkmarkColor: Colors.white,
                                      backgroundColor: card,
                                      side: BorderSide(color: active ? const Color(0xFF2563EB) : border),
                                      onSelected: (val) {
                                        setState(() {
                                          if (val) {
                                            _selectedSectionIds.add(sid);
                                          } else {
                                            _selectedSectionIds.remove(sid);
                                          }
                                        });
                                        _loadClassMembers();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  FilterChip(
                                    selected: _includeStudents,
                                    label: Text('Students (${_classStudents.length})', style: TextStyle(fontSize: 11, color: _includeStudents ? Colors.white : textPrimary)),
                                    selectedColor: const Color(0xFF10B981),
                                    checkmarkColor: Colors.white,
                                    onSelected: (v) => setState(() => _includeStudents = v),
                                  ),
                                  const SizedBox(width: 8),
                                  FilterChip(
                                    selected: _includeTeachers,
                                    label: Text('Teachers (${_classTeachers.length})', style: TextStyle(fontSize: 11, color: _includeTeachers ? Colors.white : textPrimary)),
                                    selectedColor: const Color(0xFF8B5CF6),
                                    checkmarkColor: Colors.white,
                                    onSelected: (v) => setState(() => _includeTeachers = v),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Material(
                                color: card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox(
                                  height: 145,
                                  child: _isLoadingMembers
                                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                      : combinedClassUsers.isEmpty
                                          ? Center(child: Text('Share applies to all students/teachers matching selected class & sections.', style: TextStyle(fontSize: 11.5, color: textSecondary)))
                                          : ListView.builder(
                                              itemCount: combinedClassUsers.length,
                                              itemBuilder: (ctx, i) {
                                                final u = combinedClassUsers[i];
                                                final uid = u['id']?.toString() ?? '';
                                                final checked = _selectedMembersMap.containsKey(uid);
                                                return CheckboxListTile(
                                                  dense: true,
                                                  value: checked,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      if (v == true) {
                                                        _selectedMembersMap[uid] = u;
                                                      } else {
                                                        _selectedMembersMap.remove(uid);
                                                      }
                                                    });
                                                  },
                                                  title: Text((u['full_name'] ?? 'Member').toString(), style: TextStyle(fontSize: 12, color: textPrimary)),
                                                  subtitle: Text('${u['role'] ?? 'student'}  •  ${u['section_name'] ?? ''}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                                                );
                                              },
                                            ),
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      onChanged: (v) => _searchUsers(v),
                                      style: TextStyle(fontSize: 12.5, color: textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Search student or teacher by name or email...',
                                        hintStyle: TextStyle(fontSize: 11.5, color: textSecondary),
                                        prefixIcon: Icon(Icons.search, size: 16, color: textSecondary),
                                        filled: true,
                                        fillColor: card,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: AppSearchableDropdown<String>.fromMenuItems(
                                      value: _roleFilter,
                                      isDense: true,
                                      dropdownColor: bg,
                                      style: TextStyle(fontSize: 12, color: textPrimary),
                                      items: const [
                                        DropdownMenuItem(value: '', child: Text('All Roles')),
                                        DropdownMenuItem(value: 'student', child: Text('Students')),
                                        DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                                      ],
                                      onChanged: (v) {
                                        setState(() => _roleFilter = v ?? '');
                                        _searchUsers();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedMembersMap.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _selectedMembersMap.values.map((u) {
                                    final uid = u['id']?.toString() ?? '';
                                    return Chip(
                                      label: Text((u['full_name'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                                      deleteIcon: const Icon(Icons.close, size: 14),
                                      onDeleted: () => setState(() => _selectedMembersMap.remove(uid)),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Material(
                                color: card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SizedBox(
                                  height: 170,
                                  child: _isSearchingUsers
                                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                      : _searchResults.isEmpty
                                          ? Center(child: Text('No users matched search query.', style: TextStyle(fontSize: 11.5, color: textSecondary)))
                                          : ListView.builder(
                                              itemCount: _searchResults.length,
                                              itemBuilder: (ctx, i) {
                                                final u = _searchResults[i];
                                                final uid = u['id']?.toString() ?? '';
                                                final checked = _selectedMembersMap.containsKey(uid);
                                                return CheckboxListTile(
                                                  dense: true,
                                                  value: checked,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      if (v == true) {
                                                        _selectedMembersMap[uid] = u;
                                                      } else {
                                                        _selectedMembersMap.remove(uid);
                                                      }
                                                    });
                                                  },
                                                  title: Text((u['full_name'] ?? 'User').toString(), style: TextStyle(fontSize: 12, color: textPrimary)),
                                                  subtitle: Text('${u['role'] ?? ''}  •  ${u['email'] ?? ''}', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                                                );
                                              },
                                            ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Access Level', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                      const SizedBox(height: 6),
                                      AppSearchableDropdown<String>.fromMenuItems(
                                        value: _accessLevel,
                                        isDense: true,
                                        dropdownColor: bg,
                                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                                        items: const [
                                          DropdownMenuItem(value: 'VIEW', child: Text('View Only (Stream)')),
                                          DropdownMenuItem(value: 'DOWNLOAD', child: Text('View & Download')),
                                          DropdownMenuItem(value: 'MANAGE', child: Text('Manage & Re-Share')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _accessLevel = v);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(top: 18),
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: '${Uri.base.origin}/admin/live-classes?tab=1&recording=${widget.recording.id}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Recording link copied to clipboard.')),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 14),
                                    label: const Text('Copy Link', style: TextStyle(fontSize: 11.5)),
                                  ),
                                ),
                              ],
                            ),

                            if (_activeShares.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text('Active Shares (${_activeShares.length})', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textPrimary)),
                              const SizedBox(height: 6),
                              ..._activeShares.map((sh) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(6), border: Border.all(color: border)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${sh['target_label']}  •  ${sh['access_level']}',
                                          style: TextStyle(fontSize: 11.5, color: textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _revokeShare(sh['id']?.toString() ?? ''),
                                        child: const Text('Revoke', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false), child: const Text('Close')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: (_isSubmitting || !canSubmit) ? null : _submitShare,
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_isSubmitting ? 'Sharing...' : 'Share Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeBtn(String modeKey, String label, IconData icon, Color textSecondary) {
    final active = _mode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = modeKey),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
